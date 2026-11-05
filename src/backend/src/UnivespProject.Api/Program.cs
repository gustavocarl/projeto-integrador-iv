using UnivespProject.Api.Endpoints;
using UnivespProject.Api.Errors;
using UnivespProject.Api.Extensions;
using UnivespProject.Api.Services;
using UnivespProject.Application;
using UnivespProject.Application.Abstractions;
using UnivespProject.Infrastructure;
using UnivespProject.Infrastructure.Persistence;

var builder = WebApplication.CreateBuilder(args);

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
// Invalid request bodies raise an exception (in every environment) so GlobalExceptionHandler formats them.
builder.Services.Configure<RouteHandlerOptions>(options => options.ThrowOnBadRequest = true);

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment.ContentRootPath);
builder.Services.AddJwtAuthentication(builder.Configuration);

// Allows the Flutter app (web/emulator) to call the API during development.
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

// Creates the database if it does not exist and applies pending migrations.
await app.Services.InitializeDatabaseAsync();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}
else
{
    // Tells browsers to use only HTTPS for this host from now on.
    app.UseHsts();
}

app.UseExceptionHandler();
app.UseHttpsRedirection();
app.UseCors();
// Uploaded product photos (public files, see ProductImageFilesExtensions).
app.UseProductImageFiles();

app.UseAuthentication();
app.UseAuthorization();

app.MapAuthEndpoints();
app.MapStoreEndpoints();
app.MapNotificationEndpoints();
app.MapSettingsEndpoints();
app.MapSalesEndpoints();
app.MapProductEndpoints();
app.MapAnalyticsEndpoints();

app.Run();
