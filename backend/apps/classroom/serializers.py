from rest_framework import serializers
from .models import Course, Coursework, SyncLog


class CourseworkSerializer(serializers.ModelSerializer):
    class Meta:
        model = Coursework
        fields = [
            'id', 'course', 'title', 'description', 'work_type',
            'state', 'max_points', 'due_date', 'due_time',
            'alternate_link', 'last_synced_at',
        ]


class CourseSerializer(serializers.ModelSerializer):
    class Meta:
        model = Course
        fields = [
            'id', 'name', 'section', 'description', 'room',
            'course_state', 'alternate_link', 'teacher_name', 'last_synced_at',
        ]


class SyncLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = SyncLog
        fields = [
            'id', 'sync_type', 'status', 'courses_synced',
            'coursework_synced', 'error_message', 'started_at', 'completed_at',
        ]
