from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, GoogleCredential


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['username', 'email', 'is_staff', 'created_at']
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Profile', {'fields': ('avatar_url',)}),
    )


@admin.register(GoogleCredential)
class GoogleCredentialAdmin(admin.ModelAdmin):
    list_display = ['user', 'google_email', 'expiry', 'updated_at']
    readonly_fields = ['created_at', 'updated_at']
