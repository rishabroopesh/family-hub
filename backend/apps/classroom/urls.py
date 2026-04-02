from django.urls import path
from .views import (
    CourseListView, CourseDetailView, CourseworkListView,
    TriggerSyncView, SyncStatusView, SyncLogListView,
)

urlpatterns = [
    path('courses/', CourseListView.as_view(), name='classroom-courses'),
    path('courses/<uuid:pk>/', CourseDetailView.as_view(), name='classroom-course-detail'),
    path('courses/<uuid:pk>/coursework/', CourseworkListView.as_view(), name='classroom-coursework'),
    path('sync/', TriggerSyncView.as_view(), name='classroom-sync'),
    path('sync/status/', SyncStatusView.as_view(), name='classroom-sync-status'),
    path('sync/logs/', SyncLogListView.as_view(), name='classroom-sync-logs'),
]
