from rest_framework import serializers
from .models import Workspace, WorkspaceMembership


class WorkspaceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Workspace
        fields = ['id', 'name', 'icon', 'is_personal', 'owner', 'created_at', 'updated_at']
        read_only_fields = ['id', 'owner', 'created_at', 'updated_at']


class WorkspaceMembershipSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = WorkspaceMembership
        fields = ['id', 'workspace', 'user', 'username', 'role', 'created_at']
        read_only_fields = ['id', 'created_at']
