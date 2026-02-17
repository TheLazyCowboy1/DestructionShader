using Menu.Remix.MixedUI;

namespace DestructionShader;

public class Options : OptionInterface
{
    public Options() : base()
    {
        DestructionLevel = this.config.Bind<float>("DestructionLevel", 30, new ConfigAcceptableRange<float>(0, 100));
    }

    public Configurable<float> DestructionLevel;

    public override void Initialize()
    {
        base.Initialize();

        OpTab tab = new(this, "Options");
        this.Tabs = new OpTab[] { tab };

        tab.AddItems(
            new OpFloatSlider(DestructionLevel, new(30, 300), 300, 1, false) { description = "How strong the destruction effect is. There is no strict metric for this. Just know that 60 is twice as strong as 30." },
            new OpLabel(100, 350, "Destruction Level"),
            new OpLabel(30, 280, "0%") { alignment = FLabelAlignment.Center },
            new OpLabel(130, 280, "25%") { alignment = FLabelAlignment.Center },
            new OpLabel(230, 280, "50%") { alignment = FLabelAlignment.Center },
            new OpLabel(330, 280, "100%") { alignment = FLabelAlignment.Center }
            );

    }
}
