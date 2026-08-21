Shader "Unlit/Btn1Shader"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint Color", Color) = (1, 1, 1, 1)// 按钮叠加颜色/色调

        _Aspect ("Aspect Ratio (W/H)", Float) = 3.0// 按钮的宽高比（用于纠正圆角和发光的拉伸比例）
        _CornerRadius ("Corner Radius", Range(0, 0.5)) = 0.1// 按钮圆角半径大小

        [Header(Border)]
        _BorderWidth ("Border Width", Range(0.0, 0.1)) = 0.02// 边框线宽度
        _BorderColor ("Border Color", Color) = (0.2, 0.2, 0.2, 0.5)// 边框线颜色

        [Header(Glow)]
        [HDR] _GlowColor ("Glow Color (HDR)", Color) = (0.0, 1.0, 1.0, 1.0)// 发光颜色
        _GlowSize ("Glow Size (Length)", Range(0.01, 1.5)) = 0.4// 单道发光光束的弧长长度
        _GlowSpeed ("Glow Speed", Float) = 2.0// 全局基础旋转速度
        _Light1Speed ("Light 1 Speed Mult", Float) = 1.0// 光束 1 的旋转速度与方向倍率（正值顺时针，负值逆时针）
        _Light2Speed ("Light 2 Speed Mult", Float) = -1.0// 光束 2 的旋转速度与方向倍率（正值顺时针，负值逆时针）
        _LightSeparation ("Light 2 Offset (Deg)", Range(0.0, 360.0)) = 180.0// 两道光之间的夹角/起始角度偏移（单位：度）
        _GlowIntensity ("Glow Intensity", Float) = 3.0// 发光强度（亮度）
        _InnerSoftness ("Inner Softness", Range(0.1, 100.0)) = 20.0 // 边缘内侧发光渐变羽化程度
        _OuterSoftness ("Outer Softness", Range(0.1, 100.0)) = 20.0// 边缘外侧发光渐变羽化程度

        [Header(Noise Shimmer)]
        _NoiseScale ("Noise Scale", Float) = 10.0 // 噪波缩放大小（控制发光抖动细节的频度）
        _NoiseSpeed ("Noise Speed", Float) = 5.0// 噪波变化速度（控制发光抖动的快慢）
        _NoiseStrength ("Noise Strength", Range(0.0, 0.5)) = 0.05 // 噪波扰动强度（控制光束抖动和闪烁的幅度）

        _ColorMask ("Color Mask", Float) = 15// 渲染颜色通道遮罩，默认为 15 (即 RGBA 全开)

    }
   

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }


        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "UnityCG.cginc"

            #pragma shader_feature_local UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 uv       : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            fixed4 _Color;
            fixed4 _TextureSampleAdd;
            float4 _ClipRect;
            
            float _Aspect;
            float _CornerRadius;
            float _BorderWidth;
            fixed4 _BorderColor;
            
            fixed4 _GlowColor;
            float _GlowSize;
            float _GlowSpeed;
            float _Light1Speed;
            float _Light2Speed;
            float _LightSeparation;
            float _GlowIntensity;
            float _InnerSoftness;
            float _OuterSoftness;
            
            float _NoiseScale;
            float _NoiseSpeed;
            float _NoiseStrength;

            v2f vert(appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.worldPosition = v.vertex;
                o.vertex = UnityObjectToClipPos(o.worldPosition);
                o.uv = v.texcoord;
                o.color = v.color;
                return o;
            }

            // Rounded Box SDF
            float sdRoundedBox(float2 p, float2 b, float r)
            {
                float2 q = abs(p) - b + r;
                return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
            }

            // Simple 2D Noise
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(hash(i + float2(0.0,0.0)), hash(i + float2(1.0,0.0)), u.x),
                            lerp(hash(i + float2(0.0,1.0)), hash(i + float2(1.0,1.0)), u.x), u.y);
            }

            // Custom UI 2D Clipping Function to replace UnityUI.cginc dependency
            float Get2DClippedAlpha(float2 pos, float4 clipRect)
            {
                float2 inside = step(clipRect.xy, pos) * step(pos, clipRect.zw);
                return inside.x * inside.y;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // Sample main texture (standard UI sprite)
                fixed4 texCol = (tex2D(_MainTex, i.uv) + _TextureSampleAdd) * i.color * _Color;
                
                // Aspect-ratio corrected coordinates
                float2 p = float2((i.uv.x - 0.5) * _Aspect, i.uv.y - 0.5);
                float2 b = float2(0.5 * _Aspect, 0.5);
                
                // Safety clamp corner radius
                float r = clamp(_CornerRadius, 0.0, 0.5);
                
                // Calculate Rounded Box SDF
                float d = sdRoundedBox(p, b, r);
                
                // Anti-aliased masks
                float bodyAA = smoothstep(0.002, -0.002, d);
                float borderAA = smoothstep(0.002, -0.002, d) * smoothstep(-_BorderWidth - 0.002, -_BorderWidth + 0.002, d);
                
                // Base button body and border colors
                fixed4 buttonBody = texCol * bodyAA;
                fixed4 borderColor = _BorderColor * borderAA;
                
                // Blend body and border
                fixed4 finalCol = lerp(buttonBody, borderColor, borderColor.a);
                
                // Moving Glow calculation
                float pixelAngle = atan2(p.y, p.x);
                
                // Apply Noise to angle and intensity for shimmery energy look
                float n = noise(p * _NoiseScale + _Time.y * _NoiseSpeed);
                pixelAngle += (n - 0.5) * _NoiseStrength;
                
                // Calculate moving spotlight angles for both lights
                float lightAngle1 = _Time.y * _GlowSpeed * _Light1Speed;
                float lightAngle2 = _Time.y * _GlowSpeed * _Light2Speed + (_LightSeparation * 0.0174532925);
                
                float angleDiff1 = acos(cos(pixelAngle - lightAngle1));
                float angleDiff2 = acos(cos(pixelAngle - lightAngle2));
                
                // Spotlight segments along the perimeter for both lights
                float spot1 = smoothstep(_GlowSize, 0.0, angleDiff1);
                float spot2 = smoothstep(_GlowSize, 0.0, angleDiff2);
                
                // Combine the two spotlights
                float spotIntensity = max(spot1, spot2);
                spotIntensity *= (1.0 - _NoiseStrength * 0.5) + n * _NoiseStrength * 0.5; // add subtle flicker
                
                // Soft glow falloff profile from the boundary (d = 0)
                float glowProfile = (d < 0.0) ? exp(-abs(d) * _InnerSoftness) : exp(-abs(d) * _OuterSoftness);
                
                // Combine to form the rim glow
                fixed4 glow = _GlowColor * (glowProfile * spotIntensity * _GlowIntensity);
                
                // Blend glow additively onto the button color
                finalCol.rgb += glow.rgb * glow.a;
                finalCol.a = saturate(finalCol.a + glow.a * glowProfile * spotIntensity);
                
                // Apply Canvas Clip Rect (for Scroll Views, etc.)
                #ifdef UNITY_UI_ALPHACLIP
                clip(finalCol.a - 0.001);
                #endif
                
                // Standard UI Mask Clip Rect
                finalCol.a *= Get2DClippedAlpha(i.worldPosition.xy, _ClipRect);
                
                return finalCol;
            }
            ENDCG
        }
    }
}
