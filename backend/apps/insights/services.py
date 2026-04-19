import logging
from datetime import date, datetime, time, timedelta

import anthropic
from django.conf import settings
from django.utils import timezone

from apps.calendar_app.models import CalendarEvent
from apps.classroom.models import Course, Coursework

from .models import Insight

logger = logging.getLogger(__name__)


BULLET_SYSTEM_PROMPT = """You are a concise study assistant. You will receive a coaching paragraph about a student's upcoming schedule.

Distill it into 4-7 tight, actionable bullet points. Include:
- Specific assignments, their due dates, and what to do
- Any mental health or wellness advice from the original

Rules:
- Each bullet is one clear, direct sentence
- Be specific — use real names and dates from the text
- No filler, no pleasantries, no intro sentence
- Return ONLY a JSON array of strings — no markdown, no code fences, no commentary

Example output: ["Submit the history essay by Thursday.", "Take a 10-minute walk before track practice."]"""


SYSTEM_PROMPT = """You are a warm, encouraging study and wellness coach for a student using the FamilyHub app.

You receive structured data about the student's full schedule:
- Their Google Classroom courses and upcoming assignments
- Their calendar events, including both academic deadlines and after-school commitments (sports practice, tutoring, clubs, social events, family obligations)

Your job is to write a conversational, supportive summary that helps them stay on top of their work AND take care of themselves.

Style guidelines:
- Conversational and warm, like a helpful older sibling or favorite teacher
- Concrete and specific — name actual assignments, events, and dates
- Prioritize what's most urgent or important
- Suggest practical study tips (e.g., "break this into 30-minute chunks", "review notes from last week first")
- For exams or tests, suggest prep strategies
- Keep it focused — don't overwhelm with everything at once

Wellness and balance (this is important):
- Look at how packed the day or week actually is. A day with 4 assignments, track practice, and tutoring is very different from a day with 1 assignment and nothing else.
- On heavy days, explicitly suggest when to take breaks. Recommend short mental resets: a 5-minute walk between homework and track practice, a few minutes of deep breathing before a hard exam, or stepping outside between tutoring sessions.
- Suggest realistic windows for deep work. If the student has a 3-hour block free before an event, suggest tackling the hardest task first while they're fresh.
- For especially busy stretches, name it honestly ("this is a packed day") and help them prioritize ruthlessly — what's essential vs. what can wait.
- Encourage protecting sleep and not sacrificing rest for a low-stakes assignment.
- When the calendar includes wellness-friendly things already (family dinner, movie night, rest), reinforce them — those aren't distractions, they're recovery.
- Don't be preachy about self-care. Suggest it naturally, like a coach who cares about the whole person, not just grades.

Format:
- Organize your response BY CLASS / COURSE. Each section starts with the class name in bold (e.g., **AP Chemistry**), followed by the relevant assignment or calendar item so the student immediately knows what you're talking about.
- After the per-class sections, include one short closing section for wellness/balance advice and a specific encouragement tied to something on their actual schedule.
- Use bold (**text**) for class names and key deadlines only — don't over-format.
- Keep each section to 2-3 sentences.
- If multiple assignments belong to the same class, group them together in one section."""


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

        # Gather calendar events for the same window — both classroom-derived
        # (assignment deadlines) and manual (after-school life, family, social).
        window_start_dt = timezone.make_aware(datetime.combine(today, time.min))
        window_end_dt = timezone.make_aware(datetime.combine(end, time.max))

        personal_ws = self.user.workspaces.filter(is_personal=True).first() \
            if hasattr(self.user, 'workspaces') else None
        if personal_ws is None:
            from apps.workspaces.models import Workspace
            personal_ws = Workspace.objects.filter(
                owner=self.user, is_personal=True
            ).first()

        events_by_day = {}
        total_events = 0
        if personal_ws:
            events = CalendarEvent.objects.filter(
                workspace=personal_ws,
                start_datetime__gte=window_start_dt,
                start_datetime__lte=window_end_dt,
            ).order_by('start_datetime')

            for ev in events:
                day_key = ev.start_datetime.astimezone().date().isoformat()
                events_by_day.setdefault(day_key, []).append({
                    'title': ev.title,
                    'description': (ev.description or '').replace('[demo-seed]', '').strip()[:300],
                    'start': ev.start_datetime.astimezone().isoformat(),
                    'end': ev.end_datetime.astimezone().isoformat() if ev.end_datetime else None,
                    'all_day': ev.all_day,
                    'type': ev.event_type,  # 'classroom' or 'manual'
                })
                total_events += 1

        return {
            'student_name': self.user.first_name or self.user.username,
            'today': today.isoformat(),
            'window_end': end.isoformat(),
            'window_days': window_days,
            'total_upcoming_assignments': upcoming_count,
            'total_calendar_events': total_events,
            'courses': course_data,
            'schedule_by_day': events_by_day,
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

    def summarize_to_bullets(self, content: str) -> list:
        """Ask Claude to distill an insight paragraph into actionable bullet points."""
        import json
        import re
        response = self.client.messages.create(
            model="claude-opus-4-6",
            max_tokens=1024,
            system=BULLET_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": content}],
        )
        text = next((b.text for b in response.content if b.type == "text"), "[]").strip()
        # Strip markdown code fences if present (```json ... ```)
        text = re.sub(r'^```(?:json)?\s*', '', text)
        text = re.sub(r'\s*```$', '', text)
        text = text.strip()
        try:
            bullets = json.loads(text)
            if isinstance(bullets, list):
                return [str(b) for b in bullets if b]
        except json.JSONDecodeError:
            pass
        # Fallback: parse line-by-line if Claude didn't return valid JSON
        return [line.lstrip('-•* ').strip() for line in text.splitlines() if line.strip()]

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
