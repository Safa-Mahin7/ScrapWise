"""Request/response contracts. The client never supplies its own account role."""
import re
from typing import Literal
from pydantic import BaseModel, Field, field_validator, model_validator


def normalize_mobile(value: str) -> str:
    value = re.sub(r'[\s()-]', '', value.strip())
    if re.fullmatch(r'[6-9]\d{9}', value):
        value = '+91' + value
    elif re.fullmatch(r'91[6-9]\d{9}', value):
        value = '+' + value
    if not re.fullmatch(r'\+[1-9]\d{7,14}', value):
        raise ValueError('Enter a valid mobile number (e.g. +919876543210)')
    return value


class MobileRequest(BaseModel):
    mobile: str

    @field_validator('mobile')
    @classmethod
    def mobile_valid(cls, value: str) -> str:
        return normalize_mobile(value)


class HouseholdRegistration(MobileRequest):
    full_name: str = Field(min_length=2, max_length=120)
    locality_id: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=10, max_length=128)


class TraderApplication(MobileRequest):
    full_name: str = Field(min_length=2, max_length=120)
    business_name: str = Field(min_length=2, max_length=150)
    business_address: str = Field(min_length=5, max_length=300)
    password: str = Field(min_length=10, max_length=128)


class LoginRequest(MobileRequest):
    password: str = Field(min_length=1, max_length=128)


class GoogleTokenRequest(BaseModel):
    id_token: str = Field(min_length=20, max_length=8192)


class GoogleHouseholdRegistration(MobileRequest):
    id_token: str = Field(min_length=20, max_length=8192)
    full_name: str = Field(min_length=2, max_length=120)
    locality_id: str = Field(min_length=1, max_length=100)


class GoogleLinkRequest(GoogleTokenRequest):
    password: str = Field(min_length=1, max_length=128)


class VerifyOtp(MobileRequest):
    purpose: Literal['registration', 'password_reset']
    code: str = Field(pattern=r'^\d{6}$')


class ResendOtp(MobileRequest):
    purpose: Literal['registration'] = 'registration'


class PasswordReset(MobileRequest):
    reset_token: str = Field(min_length=20)
    new_password: str = Field(min_length=10, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=256)


class LogoutRequest(BaseModel):
    refresh_token: str | None = Field(default=None, min_length=20, max_length=256)


class InviteCollector(MobileRequest):
    full_name: str = Field(min_length=2, max_length=120)


class InvitationOtpRequest(MobileRequest):
    invitation_token: str = Field(min_length=20)


class CollectorActivation(InvitationOtpRequest):
    code: str = Field(pattern=r'^\d{6}$')
    password: str = Field(min_length=10, max_length=128)


class NewMobileRequest(BaseModel):
    new_mobile: str

    @field_validator('new_mobile')
    @classmethod
    def mobile_valid(cls, value: str) -> str:
        return normalize_mobile(value)


class ChangeMobileRequest(NewMobileRequest):
    current_password: str | None = Field(default=None, min_length=1, max_length=128)
    google_id_token: str | None = Field(default=None, min_length=20, max_length=8192)

    @model_validator(mode='after')
    def requires_one_reauthentication_method(self):
        if (self.current_password is None) == (self.google_id_token is None):
            raise ValueError('Provide exactly one reauthentication method')
        return self


class ChangeMobileConfirm(NewMobileRequest):
    code: str = Field(pattern=r'^\d{6}$')


class UserResponse(BaseModel):
    user_id: str
    mobile: str
    role: Literal['household', 'collector', 'trader', 'admin']
    status: Literal['pending_phone', 'pending_approval', 'active', 'suspended', 'rejected']
    phone_verified: bool
    full_name: str | None = None


class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = 'bearer'
    expires_in: int = 3600
    refresh_expires_in: int = 30 * 24 * 3600
    user: UserResponse
