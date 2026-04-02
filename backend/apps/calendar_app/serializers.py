from rest_framework import serializers
from .models import CalendarEvent


class CalendarEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = CalendarEvent
        fields = [
            'id', 'workspace', 'title', 'description',
            'start_datetime', 'end_datetime', 'all_day', 'color',
            'event_type', 'classroom_coursework', 'created_by',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at']
