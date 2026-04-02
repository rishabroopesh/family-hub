from django.contrib.auth import get_user_model
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Workspace, WorkspaceMembership
from .serializers import WorkspaceSerializer, WorkspaceMembershipSerializer

User = get_user_model()


class WorkspaceListCreateView(generics.ListCreateAPIView):
    serializer_class = WorkspaceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Workspace.objects.filter(memberships__user=self.request.user)

    def perform_create(self, serializer):
        workspace = serializer.save(owner=self.request.user)
        WorkspaceMembership.objects.create(
            workspace=workspace,
            user=self.request.user,
            role=WorkspaceMembership.Role.OWNER,
        )


class WorkspaceDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = WorkspaceSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Workspace.objects.filter(memberships__user=self.request.user)


class MembershipListCreateView(generics.ListCreateAPIView):
    serializer_class = WorkspaceMembershipSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return WorkspaceMembership.objects.filter(workspace_id=self.kwargs['pk'])

    def create(self, request, *args, **kwargs):
        username = request.data.get('username')
        role = request.data.get('role', WorkspaceMembership.Role.EDITOR)
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
        workspace = Workspace.objects.get(pk=kwargs['pk'])
        membership, created = WorkspaceMembership.objects.get_or_create(
            workspace=workspace, user=user, defaults={'role': role}
        )
        return Response(
            WorkspaceMembershipSerializer(membership).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class MembershipDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = WorkspaceMembershipSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return WorkspaceMembership.objects.filter(workspace_id=self.kwargs['pk'])

    def get_object(self):
        return self.get_queryset().get(pk=self.kwargs['membership_pk'])
