from rest_framework import serializers
from .models import Page


class PageTreeSerializer(serializers.ModelSerializer):
    child_pages = serializers.SerializerMethodField()

    class Meta:
        model = Page
        fields = [
            'id', 'title', 'icon', 'parent_page', 'position',
            'is_favorite', 'is_archived', 'child_pages', 'created_at', 'updated_at',
        ]

    def get_child_pages(self, obj):
        children = obj.child_pages.filter(is_archived=False).order_by('position', 'created_at')
        return PageTreeSerializer(children, many=True).data


class PageDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = Page
        fields = [
            'id', 'workspace', 'parent_page', 'title', 'icon',
            'content', 'created_by', 'position', 'is_archived',
            'is_favorite', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at']
