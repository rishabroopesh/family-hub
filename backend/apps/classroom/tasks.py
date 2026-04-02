import logging
from celery import shared_task
from django.contrib.auth import get_user_model

from apps.accounts.models import GoogleCredential

logger = logging.getLogger(__name__)
User = get_user_model()


@shared_task(bind=True, max_retries=2, default_retry_delay=60)
def sync_classroom_for_user(self, user_id, sync_type='manual'):
    from .services import ClassroomSyncService
    try:
        user = User.objects.get(id=user_id)
        service = ClassroomSyncService(user)
        sync_log = service.sync_all(sync_type=sync_type)
        return {
            'user_id': user_id,
            'status': sync_log.status,
            'courses': sync_log.courses_synced,
            'coursework': sync_log.coursework_synced,
        }
    except Exception as exc:
        logger.error(f"Sync task failed for user {user_id}: {exc}")
        raise self.retry(exc=exc)


@shared_task
def sync_classroom_all_users():
    credentials = GoogleCredential.objects.select_related('user').all()
    count = credentials.count()
    for gc in credentials:
        sync_classroom_for_user.delay(gc.user.id, sync_type='periodic')
    return f"Dispatched sync for {count} users"
