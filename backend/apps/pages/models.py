import uuid
from django.conf import settings
from django.db import models


class Page(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workspace = models.ForeignKey(
        'workspaces.Workspace', on_delete=models.CASCADE, related_name='pages'
    )
    parent_page = models.ForeignKey(
        'self', on_delete=models.CASCADE, null=True, blank=True, related_name='child_pages'
    )
    title = models.CharField(max_length=500, blank=True, default='Untitled')
    icon = models.CharField(max_length=10, blank=True, default='')
    content = models.JSONField(default=list, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='created_pages'
    )
    position = models.IntegerField(default=0)
    is_archived = models.BooleanField(default=False)
    is_favorite = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'pages_page'
        ordering = ['position', 'created_at']

    def __str__(self):
        return self.title or 'Untitled'
