from django.urls import path
from .views import (
    WorkspaceListCreateView, WorkspaceDetailView,
    MembershipListCreateView, MembershipDetailView,
)

urlpatterns = [
    path('', WorkspaceListCreateView.as_view(), name='workspace-list'),
    path('<int:pk>/', WorkspaceDetailView.as_view(), name='workspace-detail'),
    path('<int:pk>/members/', MembershipListCreateView.as_view(), name='membership-list'),
    path('<int:pk>/members/<int:membership_pk>/', MembershipDetailView.as_view(), name='membership-detail'),
]
