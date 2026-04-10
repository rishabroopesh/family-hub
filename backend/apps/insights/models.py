import uuid
from django.conf import settings
from django.db import models


class Insight(models.Model):
    class InsightType(models.TextChoices):
        DAILY = 'daily', 'Daily'
        WEEKLY = 'weekly', 'Weekly'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='insights',
    )
    insight_type = models.CharField(max_length=20, choices=InsightType.choices)
    content = models.TextField()
    context_summary = models.JSONField(default=dict)
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'insights_insight'
        ordering = ['-generated_at']
        indexes = [
            models.Index(fields=['user', 'insight_type', '-generated_at']),
        ]

    def __str__(self):
        return f"{self.insight_type} insight for {self.user.username} at {self.generated_at}"
