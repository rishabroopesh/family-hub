from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Course, Coursework, SyncLog
from .serializers import CourseSerializer, CourseworkSerializer, SyncLogSerializer
from .tasks import sync_classroom_for_user


class CourseListView(generics.ListAPIView):
    serializer_class = CourseSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Course.objects.filter(user=self.request.user)


class CourseDetailView(generics.RetrieveAPIView):
    serializer_class = CourseSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Course.objects.filter(user=self.request.user)


class CourseworkListView(generics.ListAPIView):
    serializer_class = CourseworkSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Coursework.objects.filter(
            course__user=self.request.user,
            course_id=self.kwargs['pk'],
        ).order_by('due_date')


class TriggerSyncView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        sync_classroom_for_user.delay(request.user.id, sync_type='manual')
        return Response({'detail': 'Sync started.'}, status=status.HTTP_202_ACCEPTED)


class SyncStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        log = SyncLog.objects.filter(user=request.user).first()
        if not log:
            return Response({'detail': 'No sync history.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(SyncLogSerializer(log).data)


class SyncLogListView(generics.ListAPIView):
    serializer_class = SyncLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SyncLog.objects.filter(user=self.request.user)[:20]
