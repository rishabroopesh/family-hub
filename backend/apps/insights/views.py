import logging

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Insight
from .serializers import InsightSerializer
from .services import InsightsGenerator

logger = logging.getLogger(__name__)


DAILY_MAX_AGE_HOURS = 6
WEEKLY_MAX_AGE_HOURS = 24


class InsightView(APIView):
    """
    GET  /api/v1/insights/<type>/         → return a fresh-or-cached insight
    POST /api/v1/insights/<type>/refresh/ → force regenerate
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, insight_type):
        if insight_type not in (Insight.InsightType.DAILY, Insight.InsightType.WEEKLY):
            return Response({'detail': 'Invalid insight type.'}, status=status.HTTP_400_BAD_REQUEST)

        max_age = DAILY_MAX_AGE_HOURS if insight_type == Insight.InsightType.DAILY else WEEKLY_MAX_AGE_HOURS
        try:
            insight = InsightsGenerator.get_or_generate(request.user, insight_type, max_age)
        except Exception as e:
            logger.exception("Failed to generate insight")
            return Response(
                {'detail': f'Failed to generate insight: {e}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        return Response(InsightSerializer(insight).data)


class InsightRefreshView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, insight_type):
        if insight_type not in (Insight.InsightType.DAILY, Insight.InsightType.WEEKLY):
            return Response({'detail': 'Invalid insight type.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            insight = InsightsGenerator(request.user).generate(insight_type)
        except Exception as e:
            logger.exception("Failed to generate insight")
            return Response(
                {'detail': f'Failed to generate insight: {e}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        return Response(InsightSerializer(insight).data, status=status.HTTP_201_CREATED)
