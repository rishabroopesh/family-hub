import logging
from datetime import date, timedelta

import anthropic
from django.conf import settings
from django.utils import timezone

from apps.classroom.models import Course, Coursework

from .models import Insight

logger = logging.getLogger(__name__)


SYSTEM_PROMPT = """You are a friendly, encouraging study assistant for a student using the FamilyHub app.

You receive structured data about the student's Google Classroom courses, assignments, and due dates.
Your job is to write a conversational, supportive summary that helps them stay on top of their work.

Style guidelines:
- Conversational and warm, like a helpful older sibling or favorite teacher
- Concrete and specific — name actual assignments and dates
- Prioritize what's most urgent or important
- Suggest practical study tips when relevant (e.g., "break this into 30-minute chunks", "review notes from last week first")
- For exams or tests, suggest prep strategies
- Keep it focused — don't overwhelm with everything at once
- End with a small encouragement
- Use plain text, no markdown headers
- Length: 3-6 short paragraphs"""


class InsightsGenerator:
    """Pulls Classroom data for a user and generates conversational insights via Claude."""

    DAILY_WINDOW_DAYS = 1
    WEEKLY_WINDOW_DAYS = 7

    def __init__(self, user):
        self.user = user
        self.client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

    def _gather_classroom_context(self, window_days: int) -> dict:
        today = date.today()
        end = today + timedelta(days=window_days)

        courses = Course.objects.filter(user=self.user)
        course_data = []
        upcoming_count = 0

        for course in courses:
            coursework = Coursework.objects.filter(
                course=course,
                due_date__gte=today,
                due_date__lte=end,
            ).order_by('due_date')

            if not coursework.exists():
                continue

            items = []
            for cw in coursework:
                items.append({
                    'title': cw.title,
                    'description': (cw.description or '')[:500],
                    'work_type': cw.work_type,
                    'state': cw.state,
                    'max_points': float(cw.max_points) if cw.max_points else None,
                    'due_date': cw.due_date.isoformat() if cw.due_date else None,
                    'due_time': cw.due_time.isoformat() if cw.due_time else None,
                })
                upcoming_count += 1

            course_data.append({
                'name': course.name,
                'section': course.section,
                'teacher': course.teacher_name,
                'room': course.room,
                'upcoming_assignments': items,
            })

        return {
            'student_name': self.user.first_name or self.user.username,
            'today': today.isoformat(),
            'window_end': end.isoformat(),
            'window_days': window_days,
            'total_upcoming_assignments': upcoming_count,
            'courses': course_data,
        }

    def _build_user_message(self, context: dict, insight_type: str) -> str:
        if insight_type == Insight.InsightType.DAILY:
            timeframe = "the next 24 hours"
        else:
            timeframe = "the next 7 days"

        if context['total_upcoming_assignments'] == 0:
            return (
                f"Today is {context['today']}. {context['student_name']} has no assignments "
                f"due in {timeframe}. Write a brief, encouraging note suggesting they use this "
                "time to review past material, get ahead, or take a well-deserved break."
            )

        import json
        return (
            f"Today is {context['today']}. Generate a {insight_type} summary for {context['student_name']} "
            f"covering {timeframe}. Here is their classroom data:\n\n"
            f"{json.dumps(context, indent=2)}"
        )

    def generate(self, insight_type: str) -> Insight:
        if insight_type == Insight.InsightType.DAILY:
            window_days = self.DAILY_WINDOW_DAYS
        elif insight_type == Insight.InsightType.WEEKLY:
            window_days = self.WEEKLY_WINDOW_DAYS
        else:
            raise ValueError(f"Unknown insight type: {insight_type}")

        context = self._gather_classroom_context(window_days)
        user_message = self._build_user_message(context, insight_type)

        logger.info(
            "Generating %s insight for user %s (%d upcoming assignments)",
            insight_type, self.user.username, context['total_upcoming_assignments'],
        )

        response = self.client.messages.create(
            model="claude-opus-4-6",
            max_tokens=16000,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )

        text = next((b.text for b in response.content if b.type == "text"), "")

        return Insight.objects.create(
            user=self.user,
            insight_type=insight_type,
            content=text,
            context_summary={
                'total_upcoming_assignments': context['total_upcoming_assignments'],
                'course_count': len(context['courses']),
                'window_days': window_days,
            },
        )

    @classmethod
    def get_or_generate(cls, user, insight_type: str, max_age_hours: int) -> Insight:
        """Return the most recent insight if it's fresh enough, otherwise generate a new one."""
        cutoff = timezone.now() - timedelta(hours=max_age_hours)
        recent = Insight.objects.filter(
            user=user,
            insight_type=insight_type,
            generated_at__gte=cutoff,
        ).first()
        if recent:
            return recent
        return cls(user).generate(insight_type)
