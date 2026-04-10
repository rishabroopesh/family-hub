from django.urls import path

from .views import InsightView, InsightRefreshView

urlpatterns = [
    path('<str:insight_type>/', InsightView.as_view(), name='insight-detail'),
    path('<str:insight_type>/refresh/', InsightRefreshView.as_view(), name='insight-refresh'),
]
