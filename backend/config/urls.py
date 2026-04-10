from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/auth/', include('apps.accounts.urls')),
    path('api/v1/workspaces/', include('apps.workspaces.urls')),
    path('api/v1/pages/', include('apps.pages.urls')),
    path('api/v1/calendar/', include('apps.calendar_app.urls')),
    path('api/v1/classroom/', include('apps.classroom.urls')),
    path('api/v1/insights/', include('apps.insights.urls')),
]
