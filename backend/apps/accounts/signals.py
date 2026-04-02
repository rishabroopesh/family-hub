from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def create_personal_workspace(sender, instance, created, **kwargs):
    if created:
        from apps.workspaces.models import Workspace, WorkspaceMembership
        workspace = Workspace.objects.create(
            name=f"{instance.username}'s Workspace",
            owner=instance,
            is_personal=True,
            icon='🏠',
        )
        WorkspaceMembership.objects.create(
            workspace=workspace,
            user=instance,
            role=WorkspaceMembership.Role.OWNER,
        )
