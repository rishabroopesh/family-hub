from django.contrib.auth import authenticate, get_user_model
from django.conf import settings
from django.core import signing
from google_auth_oauthlib.flow import Flow
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import GoogleCredential
from .serializers import UserSerializer, RegisterSerializer, LoginSerializer

User = get_user_model()

CLASSROOM_SCOPES = [
    'https://www.googleapis.com/auth/classroom.courses.readonly',
    'https://www.googleapis.com/auth/classroom.coursework.students.readonly',
    'https://www.googleapis.com/auth/classroom.rosters.readonly',
]


def _create_flow():
    client_config = {
        'web': {
            'client_id': settings.GOOGLE_CLIENT_ID,
            'client_secret': settings.GOOGLE_CLIENT_SECRET,
            'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
            'token_uri': 'https://oauth2.googleapis.com/token',
            'redirect_uris': [settings.GOOGLE_REDIRECT_URI],
        }
    }
    return Flow.from_client_config(
        client_config,
        scopes=CLASSROOM_SCOPES,
        redirect_uri=settings.GOOGLE_REDIRECT_URI,
    )


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response(
            {'user': UserSerializer(user).data, 'token': token.key},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        user = authenticate(
            username=serializer.validated_data['username'],
            password=serializer.validated_data['password'],
        )
        if not user:
            return Response(
                {'detail': 'Invalid credentials.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        token, _ = Token.objects.get_or_create(user=user)
        return Response({'user': UserSerializer(user).data, 'token': token.key})


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        request.user.auth_token.delete()
        return Response({'detail': 'Logged out.'}, status=status.HTTP_200_OK)


class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)


class GoogleOAuthConnectView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not settings.GOOGLE_CLIENT_ID:
            return Response(
                {'detail': 'Google OAuth is not configured.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        flow = _create_flow()
        state = signing.dumps({'user_id': request.user.id})
        auth_url, _ = flow.authorization_url(
            access_type='offline',
            include_granted_scopes='true',
            prompt='consent',
            state=state,
        )
        return Response({'auth_url': auth_url})


class GoogleOAuthCallbackView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        code = request.query_params.get('code')
        state = request.query_params.get('state')
        error = request.query_params.get('error')

        if error:
            return Response({'detail': f'Google OAuth error: {error}'}, status=status.HTTP_400_BAD_REQUEST)

        if not code or not state:
            return Response({'detail': 'Missing code or state.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payload = signing.loads(state, max_age=600)
            user_id = payload['user_id']
        except (signing.BadSignature, KeyError):
            return Response({'detail': 'Invalid or expired state.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        flow = _create_flow()
        flow.fetch_token(code=code)
        credentials = flow.credentials

        GoogleCredential.objects.update_or_create(
            user=user,
            defaults={
                'access_token': credentials.token,
                'refresh_token': credentials.refresh_token or '',
                'token_uri': credentials.token_uri,
                'client_id': credentials.client_id,
                'client_secret': credentials.client_secret,
                'scopes': list(credentials.scopes or []),
                'expiry': credentials.expiry,
            },
        )
        return Response({'success': True, 'message': 'Google Classroom connected successfully.'})


class GoogleOAuthDisconnectView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request):
        try:
            request.user.google_credential.delete()
        except GoogleCredential.DoesNotExist:
            pass
        return Response({'detail': 'Google account disconnected.'})


class GoogleOAuthStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            gc = request.user.google_credential
            return Response({'connected': True, 'google_email': gc.google_email})
        except GoogleCredential.DoesNotExist:
            return Response({'connected': False, 'google_email': ''})
