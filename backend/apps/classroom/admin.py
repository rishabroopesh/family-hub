from django.contrib import admin
from .models import Course, Coursework, SyncLog


@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    list_display = ['name', 'user', 'section', 'course_state', 'last_synced_at']
    list_filter = ['course_state']


@admin.register(Coursework)
class CourseworkAdmin(admin.ModelAdmin):
    list_display = ['title', 'course', 'work_type', 'due_date', 'max_points']
    list_filter = ['work_type', 'state']


@admin.register(SyncLog)
class SyncLogAdmin(admin.ModelAdmin):
    list_display = ['user', 'sync_type', 'status', 'courses_synced', 'coursework_synced', 'started_at']
    list_filter = ['status', 'sync_type']
    readonly_fields = ['started_at', 'completed_at']
