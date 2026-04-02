import uuid
from django.conf import settings
from django.db import models


class Course(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='classroom_courses',
    )
    google_course_id = models.CharField(max_length=255, db_index=True)
    name = models.CharField(max_length=500)
    section = models.CharField(max_length=255, blank=True, default='')
    description = models.TextField(blank=True, default='')
    room = models.CharField(max_length=255, blank=True, default='')
    course_state = models.CharField(max_length=50, blank=True, default='')
    alternate_link = models.URLField(blank=True, default='')
    teacher_name = models.CharField(max_length=255, blank=True, default='')
    raw_json = models.JSONField(default=dict)
    last_synced_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'classroom_course'
        unique_together = ('user', 'google_course_id')

    def __str__(self):
        return self.name


class Coursework(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    course = models.ForeignKey(
        Course, on_delete=models.CASCADE, related_name='coursework_items'
    )
    google_coursework_id = models.CharField(max_length=255, db_index=True)
    title = models.CharField(max_length=500)
    description = models.TextField(blank=True, default='')
    work_type = models.CharField(max_length=50, blank=True, default='')
    state = models.CharField(max_length=50, blank=True, default='')
    max_points = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    due_date = models.DateField(null=True, blank=True)
    due_time = models.TimeField(null=True, blank=True)
    alternate_link = models.URLField(blank=True, default='')
    raw_json = models.JSONField(default=dict)
    last_synced_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'classroom_coursework'
        unique_together = ('course', 'google_coursework_id')

    def __str__(self):
        return self.title


class SyncLog(models.Model):
    class Status(models.TextChoices):
        STARTED = 'started', 'Started'
        SUCCESS = 'success', 'Success'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sync_logs',
    )
    sync_type = models.CharField(max_length=50)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.STARTED
    )
    courses_synced = models.IntegerField(default=0)
    coursework_synced = models.IntegerField(default=0)
    error_message = models.TextField(blank=True, default='')
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'classroom_sync_log'
        ordering = ['-started_at']

    def __str__(self):
        return f"SyncLog({self.user.username}, {self.status})"
