from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    email: EmailStr
    full_name: str = ""
    password: str
    preferred_language: str = "en"

class UserOut(BaseModel):
    id: str
    email: str
    full_name: str
    preferred_language: str
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
