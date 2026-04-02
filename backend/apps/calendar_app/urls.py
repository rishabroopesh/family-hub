from django.urls import path
from .views import EventListCreateView, EventDetailView

urlpatterns = [
    path('events/', EventListCreateView.as_view(), name='event-list'),
    path('events/<uuid:pk>/', EventDetailView.as_view(), name='event-detail'),
]
