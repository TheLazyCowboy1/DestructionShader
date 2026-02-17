using System;
using System.Security;
using System.Security.Permissions;
using BepInEx;
using System.Runtime.CompilerServices;
using System.IO;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

#pragma warning disable CS0618

[module: UnverifiableCode]
[assembly: SecurityPermission(SecurityAction.RequestMinimum, SkipVerification = true)]

namespace DestructionShader;

[BepInPlugin(MOD_ID, MOD_NAME, MOD_VERSION)]
public partial class Plugin : BaseUnityPlugin
{
    public const string MOD_ID = "LazyCowboy.DestructionShader",
        MOD_NAME = "Destruction Shader",
        MOD_VERSION = "0.0.1";


    public static Plugin Instance;
    private static Options ConfigOptions;

    #region Setup
    public Plugin()
    {
    }
    private void OnEnable()
    {
        try
        {
            Instance = this;
            ConfigOptions = new Options();
        }
        catch (Exception ex)
        {
            Logger.LogError(ex);
            throw;
        }

        try
        {
            On.RainWorld.OnModsInit += RainWorld_OnModsInit;
        }
        catch (Exception ex) { Error(ex); }
    }
    private void OnDisable()
    {
        IsInit = false;

        On.RainWorld.OnModsInit -= RainWorld_OnModsInit;

        On.RoomCamera.ApplyPositionChange -= RoomCamera_ApplyPositionChange;
    }

    private bool IsInit = false;
    private void RainWorld_OnModsInit(On.RainWorld.orig_OnModsInit orig, RainWorld self)
    {
        orig(self);
        try
        {
            Init();
        }
        catch (Exception ex)
        {
            Error(ex);
            throw;
        }
    }
    private void Init()
    {
        if (IsInit) return;
        IsInit = true; //set IsInit first, in case there is an error

        //Apply hooks
        On.RoomCamera.ApplyPositionChange += RoomCamera_ApplyPositionChange;

        //Set up config menu
        MachineConnector.SetRegisteredOI(MOD_ID, ConfigOptions);

        //Load assets
        AssetBundle assets = AssetBundle.LoadFromFile(AssetManager.ResolveFilePath(Path.Combine("AssetBundles", "MVM.assets"))); //cuz I'm too lazy to make a separate assetbundle
        DestructionEffect = assets.LoadAsset<Shader>("DestructionShader.shader");
        if (DestructionEffect == null) Error("DestructionShader.shader is null!");
        DestructionMat = new(DestructionEffect);

        Log($"Initialized DestructionShader config and assets.", 0);
    }

    private static Shader DestructionEffect;
    public static Material DestructionMat;


    #endregion

    #region Hooks

    private string PoleMapRoom = "";
    private Texture2D PoleMap = null;

    private void RoomCamera_ApplyPositionChange(On.RoomCamera.orig_ApplyPositionChange orig, RoomCamera self)
    {
        orig(self);

        try
        {
            Shader.SetGlobalFloat("TheLazyCowboy1_DestructionStrength", ConfigOptions.DestructionLevel.Value * 2); //* 2 because I want the cap to be 200

            //create pole map
            Room.Tile[,] tiles = self.room.Tiles;
            int tileWidth = tiles.GetLength(0), tileHeight = tiles.GetLength(1);

            if (self.room.abstractRoom.name != PoleMapRoom || PoleMap == null) //don't generate more than is necessary
            {
                PoleMapRoom = self.room.abstractRoom.name;

                //5 pixels per tile, because poles are 4 pixels thick
                int pixelWidth = tileWidth * 5, pixelHeight = tileHeight * 5;
                if (PoleMap == null || PoleMap.width != pixelWidth || PoleMap.height != pixelHeight) //reset only if necessary
                    PoleMap = new(pixelWidth, pixelHeight, TextureFormat.R8, false) { filterMode = 0 }; //ONLY encodes red
                Color[] colors = PoleMap.GetPixels();

                for (int i = 0; i < tileWidth; i++)
                {
                    for (int j = 0; j < tileHeight; j++)
                    {
                        Room.Tile tile = tiles[i, j];
                        //fill this tile with black
                        for (int b = 0; b < 5; b++)
                        {
                            for (int a = 0; a < 5; a++)
                            {
                                //white if inside a beam; otherwise black
                                colors[(i*5 + a) + pixelWidth*(j*5 + b)].r = (tile.horizontalBeam && b == 2 || tile.verticalBeam && a == 2) ? 1 : 0;
                            }
                        }
                    }
                }
                PoleMap.SetPixels(colors);
                PoleMap.Apply();
                Shader.SetGlobalTexture("TheLazyCowboy1_PoleMap", PoleMap);

                //File.WriteAllBytes(AssetManager.ResolveFilePath("testPoleMap.png"), PoleMap.EncodeToPNG()); //as a temporary debug measure
            }

            //describe transform from levelTex to poleMap

            //poleMap.xy = i.uv * map.zw + map.xy
            Vector2 camPos = self.CamPos(self.currentCameraPosition);
            float w = tileWidth * 20, h = tileHeight * 20;
            Vector4 poleMapPos = new(camPos.x / w, camPos.y / h, self.levelTexture.width / w, self.levelTexture.height / h);
            Shader.SetGlobalVector("TheLazyCowboy1_PoleMapPos", poleMapPos);

            //generate destroyed level texture

            CommandBuffer buff = new();
            RenderTexture tempTex = new(self.levelTexture.width, self.levelTexture.height, 0, DefaultFormat.LDR) { filterMode = 0 };
            buff.Blit(self.levelTexture, tempTex, DestructionMat);
            buff.CopyTexture(tempTex, self.levelTexture);
            if (self.snowChange)
                Graphics.ExecuteCommandBuffer(buff); //don't run async if there's snow!
            else
                Graphics.ExecuteCommandBufferAsync(buff, ComputeQueueType.Default); //make this process async!
        }
        catch (Exception ex) { Error(ex); }
    }

    #endregion


    #region Tools

    public static void Log(object o, int logLevel = 1, [CallerFilePath] string file = "", [CallerMemberName] string name = "", [CallerLineNumber] int line = -1)
    {
        //if (logLevel <= Options.LogLevel)
            Instance.Logger.LogDebug(logText(o, file, name, line));
    }

    public static void Error(object o, [CallerFilePath] string file = "", [CallerMemberName] string name = "", [CallerLineNumber] int line = -1)
        => Instance.Logger.LogError(logText(o, file, name, line));

    private static DateTime PluginStartTime = DateTime.Now;
    [MethodImpl(MethodImplOptions.AggressiveInlining)]
    private static string logText(object o, string file, string name, int line)
    {
        try
        {
            return $"[{DateTime.Now.Subtract(PluginStartTime)},{Path.GetFileName(file)}.{name}:{line}]: {o}";
        }
        catch (Exception ex)
        {
            Instance.Logger.LogError(ex);
        }
        return o.ToString();
    }

    #endregion

}
