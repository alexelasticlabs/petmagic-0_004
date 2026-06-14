namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateWatermarkSettings
{
    public Guid Id { get; set; }

    public bool Enabled { get; set; }

    public string Text { get; set; } = "Made with PetMagic";

    public string? LogoUrl { get; set; }

    public double Opacity { get; set; } = 0.55;

    public string Position { get; set; } = "bottom-right";

    public string Size { get; set; } = "small";

    public int CostCredits { get; set; } = 1;

    public bool ApplyToImages { get; set; } = true;

    public bool ApplyToVideos { get; set; } = true;

    public string PreviewImageUrl { get; set; } = string.Empty;

    public string PreviewVideoFrameUrl { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
