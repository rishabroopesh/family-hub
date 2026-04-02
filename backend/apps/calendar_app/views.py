from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated

from .models import CalendarEvent
from .serializers import CalendarEventSerializer


class EventListCreateView(generics.ListCreateAPIView):
    serializer_class = CalendarEventSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = CalendarEvent.objects.filter(
            workspace__memberships__user=self.request.user
        )
        workspace_id = self.request.query_params.get('workspace')
        if workspace_id:
            qs = qs.filter(workspace_id=workspace_id)
        start = self.request.query_params.get('start')
        end = self.request.query_params.get('end')
        if start:
            qs = qs.filter(start_datetime__gte=start)
        if end:
            qs = qs.filter(start_datetime__lte=end)
        return qs.order_by('start_datetime')

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class EventDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CalendarEventSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return CalendarEvent.objects.filter(
            workspace__memberships__user=self.request.user
        )
