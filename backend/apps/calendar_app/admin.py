from django.contrib import admin
from .models import CalendarEvent


@admin.register(CalendarEvent)
class CalendarEventAdmin(admin.ModelAdmin):
    list_display = ['title', 'workspace', 'event_type', 'start_datetime', 'all_day']
    list_filter = ['event_type', 'all_day']
