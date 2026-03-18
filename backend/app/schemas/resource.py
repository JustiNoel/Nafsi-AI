from pydantic import BaseModel

class ResourceOut(BaseModel):
    id: str
    name: str
    resource_type: str
    country: str
    phone: str | None
    url: str | None
    languages: str
    is_free: bool
    description: str | None
    class Config:
        from_attributes = True
