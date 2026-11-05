using UnivespProject.Domain.Common;

namespace UnivespProject.Tests.Domain;

public class BaseEntityTests
{
    private sealed class FakeEntity : BaseEntity;

    [Fact]
    public void NewEntity_HasIdAndCreationDate_AndNoUpdateInfo()
    {
        var entity = new FakeEntity();

        Assert.NotEqual(Guid.Empty, entity.Id);
        Assert.Equal(DateTimeKind.Utc, entity.CreatedAt.Kind);
        Assert.Null(entity.UpdatedAt);
        Assert.Null(entity.UpdatedBy);
    }

    [Fact]
    public void BaseEntity_IsAbstract()
    {
        Assert.True(typeof(BaseEntity).IsAbstract);
    }
}
