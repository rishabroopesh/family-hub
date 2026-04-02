from django.urls import path
from .views import PageListCreateView, PageDetailView, FavoritePagesView

urlpatterns = [
    path('', PageListCreateView.as_view(), name='page-list'),
    path('favorites/', FavoritePagesView.as_view(), name='page-favorites'),
    path('<uuid:pk>/', PageDetailView.as_view(), name='page-detail'),
]
