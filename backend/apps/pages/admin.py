from django.contrib import admin
from .models import Page


@admin.register(Page)
class PageAdmin(admin.ModelAdmin):
    list_display = ['title', 'workspace', 'created_by', 'is_archived', 'updated_at']
    list_filter = ['is_archived', 'is_favorite']
    search_fields = ['title']
