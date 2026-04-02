from django.urls import path
from .views import (
    RegisterView, LoginView, LogoutView, UserProfileView,
    GoogleOAuthConnectView, GoogleOAuthCallbackView,
    GoogleOAuthDisconnectView, GoogleOAuthStatusView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='auth-register'),
    path('login/', LoginView.as_view(), name='auth-login'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
    path('me/', UserProfileView.as_view(), name='auth-me'),
    path('google/connect/', GoogleOAuthConnectView.as_view(), name='google-connect'),
    path('google/callback/', GoogleOAuthCallbackView.as_view(), name='google-callback'),
    path('google/disconnect/', GoogleOAuthDisconnectView.as_view(), name='google-disconnect'),
    path('google/status/', GoogleOAuthStatusView.as_view(), name='google-status'),
]
