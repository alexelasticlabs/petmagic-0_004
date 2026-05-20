using FluentValidation;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Api.Endpoints;
using PetMagic.Modules.SupportChat.Api.Realtime;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Application.Validation;

namespace PetMagic.Modules.SupportChat.Api;

public static class SupportChatApiModule
{
    public static IServiceCollection AddSupportChatApiModule(this IServiceCollection services)
    {
        services.AddSignalR();
        services.AddScoped<ISupportChatRealtimeNotifier, SignalRSupportChatRealtimeNotifier>();
        services.AddScoped<IValidator<OpenSupportConversationCommand>, OpenSupportConversationCommandValidator>();
        services.AddScoped<IValidator<SendSupportMessageCommand>, SendSupportMessageCommandValidator>();
        services.AddScoped<IValidator<MarkSupportConversationReadCommand>, MarkSupportConversationReadCommandValidator>();
        services.AddScoped<IValidator<UpdateSupportConversationStatusCommand>, UpdateSupportConversationStatusCommandValidator>();
        services.AddScoped<IValidator<AssignSupportConversationCommand>, AssignSupportConversationCommandValidator>();
        services.AddScoped<IValidator<UpsertSupportReplyTemplateCommand>, UpsertSupportReplyTemplateCommandValidator>();
        services.AddScoped<IValidator<DeleteSupportReplyTemplateCommand>, DeleteSupportReplyTemplateCommandValidator>();
        return services;
    }

    public static IApplicationBuilder MapSupportChatApiModule(this WebApplication app)
    {
        app.MapSupportChatEndpoints();
        app.MapHub<SupportChatHub>(SupportChatHub.RoutePattern);
        return app;
    }
}