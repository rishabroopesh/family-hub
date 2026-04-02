from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Page
from .serializers import PageTreeSerializer, PageDetailSerializer


class PageListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        workspace_id = request.query_params.get('workspace')
        if not workspace_id:
            return Response({'detail': 'workspace query param required.'}, status=400)
        pages = Page.objects.filter(
            workspace_id=workspace_id,
            workspace__memberships__user=request.user,
            parent_page__isnull=True,
            is_archived=False,
        ).order_by('position', 'created_at')
        return Response(PageTreeSerializer(pages, many=True).data)

    def post(self, request):
        serializer = PageDetailSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save(created_by=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class PageDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_page(self, pk, user):
        try:
            return Page.objects.get(pk=pk, workspace__memberships__user=user)
        except Page.DoesNotExist:
            return None

    def get(self, request, pk):
        page = self.get_page(pk, request.user)
        if not page:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(PageDetailSerializer(page).data)

    def patch(self, request, pk):
        page = self.get_page(pk, request.user)
        if not page:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = PageDetailSerializer(page, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response(serializer.data)

    def delete(self, request, pk):
        page = self.get_page(pk, request.user)
        if not page:
            return Response({'detail': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        page.is_archived = True
        page.save(update_fields=['is_archived'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class FavoritePagesView(generics.ListAPIView):
    serializer_class = PageDetailSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Page.objects.filter(
            workspace__memberships__user=self.request.user,
            is_favorite=True,
            is_archived=False,
        )
