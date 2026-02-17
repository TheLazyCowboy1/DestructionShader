using Menu.Remix.MixedUI;

namespace DestructionShader;

public class Options : OptionInterface
{
    public Options() : base()
    {
        DestructionLevel = this.config.Bind<float>("DestructionLevel", 20, new ConfigAcceptableRange<float>(0, 100));
    }

    public Configurable<float> DestructionLevel;

    public override void Initialize()
    {
        base.Initialize();

        OpTab tab = new(this, "Options");
        this.Tabs = new OpTab[] { tab };

        tab.AddItems(
            //new OpSlider(DestructionLevel, new(50, 300), 480) { description = "How strong the destruction effect is. There is no strict metric for this. Just know that 60 is twice as strong as 30." },
            new OpFloatSlider(DestructionLevel, new(50, 300), 480, 1, false) { Increment = 1, description = "How strong the destruction effect is. There is no strict metric for this. Just know that 60 is twice as strong as 30." },
            new OpLabel(200, 350, "Destruction Level"),
            new OpLabel(40, 280, "0%"),
            new OpLabel(160, 280, "25%"),
            new OpLabel(280, 280, "50%"),
            new OpLabel(400, 280, "50%"),
            new OpLabel(520, 280, "100%")
            );

    }
}
