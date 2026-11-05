using Microsoft.AspNetCore.Http;
using UnivespProject.Api.Errors;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Tests.Api;

public class ErrorResponseTests
{
    [Fact]
    public void StatusFor_ValidationOnly_Is400()
    {
        Assert.Equal(StatusCodes.Status400BadRequest,
            ErrorResponse.StatusFor([new Notification("email", "x")]));
    }

    [Fact]
    public void StatusFor_UsesMostRestrictiveType()
    {
        Notification[] notifications =
        [
            new("email", "x"),
            new("", "y", NotificationType.Conflict),
            new("", "z", NotificationType.Unauthorized)
        ];

        Assert.Equal(StatusCodes.Status401Unauthorized, ErrorResponse.StatusFor(notifications));
    }

    [Fact]
    public void StatusFor_Forbidden_Is403_AboveNotFound()
    {
        Notification[] notifications =
        [
            new("", "x", NotificationType.NotFound),
            new("store", "y", NotificationType.Forbidden)
        ];

        Assert.Equal(StatusCodes.Status403Forbidden, ErrorResponse.StatusFor(notifications));
    }
}
