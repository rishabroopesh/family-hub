from django.core.management.base import BaseCommand
from django_celery_beat.models import IntervalSchedule, PeriodicTask


class Command(BaseCommand):
    help = 'Create the periodic Google Classroom sync task'

    def handle(self, *args, **options):
        schedule, _ = IntervalSchedule.objects.get_or_create(
            every=30,
            period=IntervalSchedule.MINUTES,
        )
        task, created = PeriodicTask.objects.update_or_create(
            name='Sync Google Classroom for all users',
            defaults={
                'task': 'apps.classroom.tasks.sync_classroom_all_users',
                'interval': schedule,
                'enabled': True,
            },
        )
        verb = 'Created' if created else 'Updated'
        self.stdout.write(self.style.SUCCESS(f'{verb} periodic sync task (every 30 minutes).'))
