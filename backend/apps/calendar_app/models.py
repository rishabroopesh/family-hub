import uuid
from django.conf import settings
from django.db import models


class CalendarEvent(models.Model):
    class EventType(models.TextChoices):
        MANUAL = 'manual', 'Manual'
        CLASSROOM = 'classroom', 'From Google Classroom'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(
        'workspaces.Workspace', on_delete=models.CASCADE, related_name='calendar_events'
    )
    title = models.CharField(max_length=500)
    description = models.TextField(blank=True, default='')
    start_datetime = models.DateTimeField()
    end_datetime = models.DateTimeField(null=True, blank=True)
    all_day = models.BooleanField(default=False)
    color = models.CharField(max_length=20, blank=True, default='')
    event_type = models.CharField(
        max_length=20, choices=EventType.choices, default=EventType.MANUAL
    )
    classroom_coursework = models.ForeignKey(
        'classroom.Coursework',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='calendar_events',
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'calendar_event'
        ordering = ['start_datetime']

    def __str__(self):
        return self.title
