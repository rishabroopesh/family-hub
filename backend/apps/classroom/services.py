import datetime
import logging

from django.utils import timezone
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from apps.accounts.models import GoogleCredential
from .models import Course, Coursework, SyncLog

logger = logging.getLogger(__name__)


class ClassroomSyncService:
    SCOPES = [
        'https://www.googleapis.com/auth/classroom.courses.readonly',
        'https://www.googleapis.com/auth/classroom.coursework.students.readonly',
        'https://www.googleapis.com/auth/classroom.rosters.readonly',
    ]

    def __init__(self, user):
        self.user = user
        self.service = None
        self.sync_log = None

    def _get_credentials(self):
        try:
            gc = self.user.google_credential
        except GoogleCredential.DoesNotExist:
            raise ValueError("User has no Google credentials. Please connect Google Classroom first.")

        creds = Credentials(
            token=gc.access_token,
            refresh_token=gc.refresh_token,
            token_uri=gc.token_uri,
            client_id=gc.client_id,
            client_secret=gc.client_secret,
            scopes=gc.scopes,
        )

        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            gc.access_token = creds.token
            gc.expiry = creds.expiry
            gc.save(update_fields=['access_token', 'expiry', 'updated_at'])

        return creds

    def _build_service(self):
        creds = self._get_credentials()
        self.service = build('classroom', 'v1', credentials=creds)

    def sync_all(self, sync_type='manual'):
        self.sync_log = SyncLog.objects.create(
            user=self.user,
            sync_type=sync_type,
            status=SyncLog.Status.STARTED,
        )
        try:
            self._build_service()
            courses = self._sync_courses()
            cw_count = 0
            for course in courses:
                cw_count += self._sync_coursework(course)

            self.sync_log.courses_synced = len(courses)
            self.sync_log.coursework_synced = cw_count
            self.sync_log.status = SyncLog.Status.SUCCESS
            self.sync_log.completed_at = timezone.now()
            self.sync_log.save()

        except Exception as exc:
            logger.error(f"Sync failed for user {self.user.id}: {exc}")
            self.sync_log.status = SyncLog.Status.FAILED
            self.sync_log.error_message = str(exc)
            self.sync_log.completed_at = timezone.now()
            self.sync_log.save()
            raise

        return self.sync_log

    def _sync_courses(self):
        results = []
        page_token = None

        while True:
            response = self.service.courses().list(
                pageSize=100,
                courseStates=['ACTIVE'],
                pageToken=page_token,
            ).execute()

            for course_data in response.get('courses', []):
                course, _ = Course.objects.update_or_create(
                    user=self.user,
                    google_course_id=course_data['id'],
                    defaults={
                        'name': course_data.get('name', ''),
                        'section': course_data.get('section', ''),
                        'description': course_data.get('descriptionHeading', ''),
                        'room': course_data.get('room', ''),
                        'course_state': course_data.get('courseState', ''),
                        'alternate_link': course_data.get('alternateLink', ''),
                        'raw_json': course_data,
                    },
                )
                results.append(course)

            page_token = response.get('nextPageToken')
            if not page_token:
                break

        return results

    def _sync_coursework(self, course):
        count = 0
        page_token = None

        while True:
            try:
                response = self.service.courses().courseWork().list(
                    courseId=course.google_course_id,
                    pageSize=100,
                    pageToken=page_token,
                ).execute()
            except HttpError as e:
                if e.resp.status == 404:
                    break
                raise

            for cw_data in response.get('courseWork', []):
                due_date = None
                due_time = None

                if 'dueDate' in cw_data:
                    d = cw_data['dueDate']
                    due_date = datetime.date(d['year'], d['month'], d['day'])

                if 'dueTime' in cw_data:
                    t = cw_data['dueTime']
                    due_time = datetime.time(
                        t.get('hours', 23), t.get('minutes', 59)
                    )

                cw, _ = Coursework.objects.update_or_create(
                    course=course,
                    google_coursework_id=cw_data['id'],
                    defaults={
                        'title': cw_data.get('title', ''),
                        'description': cw_data.get('description', ''),
                        'work_type': cw_data.get('workType', ''),
                        'state': cw_data.get('state', ''),
                        'max_points': cw_data.get('maxPoints'),
                        'due_date': due_date,
                        'due_time': due_time,
                        'alternate_link': cw_data.get('alternateLink', ''),
                        'raw_json': cw_data,
                    },
                )

                if due_date:
                    self._upsert_calendar_event(cw, course)

                count += 1

            page_token = response.get('nextPageToken')
            if not page_token:
                break

        return count

    def _upsert_calendar_event(self, coursework, course):
        from apps.workspaces.models import Workspace
        from apps.calendar_app.models import CalendarEvent

        workspace = Workspace.objects.filter(
            owner=self.user, is_personal=True
        ).first()
        if not workspace:
            return

        due_datetime = datetime.datetime.combine(
            coursework.due_date,
            coursework.due_time or datetime.time(23, 59),
        )
        due_datetime = timezone.make_aware(due_datetime)

        CalendarEvent.objects.update_or_create(
            classroom_coursework=coursework,
            workspace=workspace,
            defaults={
                'title': f'[{course.name}] {coursework.title}',
                'description': coursework.description,
                'start_datetime': due_datetime,
                'end_datetime': due_datetime + datetime.timedelta(hours=1),
                'all_day': False,
                'event_type': CalendarEvent.EventType.CLASSROOM,
                'color': '#4285f4',
                'created_by': self.user,
            },
        )
