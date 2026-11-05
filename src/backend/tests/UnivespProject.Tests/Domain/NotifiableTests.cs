using UnivespProject.Domain.Notifications;

namespace UnivespProject.Tests.Domain;

public class NotifiableTests
{
    private sealed class FakeNotifiable : Notifiable
    {
        public void Fail(string key, string message) => AddNotification(key, message);
        public void Reset() => ClearNotifications();
    }

    [Fact]
    public void IsValid_ReflectsNotifications()
    {
        var notifiable = new FakeNotifiable();
        Assert.True(notifiable.IsValid);

        notifiable.Fail("campo", "erro");
        Assert.False(notifiable.IsValid);
        Assert.Equal(new Notification("campo", "erro"), Assert.Single(notifiable.Notifications));

        notifiable.Reset();
        Assert.True(notifiable.IsValid);
    }

    [Fact]
    public void Notifiable_IsAbstract()
    {
        Assert.True(typeof(Notifiable).IsAbstract);
    }
}
