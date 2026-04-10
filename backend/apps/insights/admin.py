from django.contrib import admin

from .models import Insight


@admin.register(Insight)
class InsightAdmin(admin.ModelAdmin):
    list_display = ('user', 'insight_type', 'generated_at')
    list_filter = ('insight_type', 'generated_at')
    search_fields = ('user__username', 'content')
    readonly_fields = ('generated_at',)
