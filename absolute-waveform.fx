texture tex : WAVEFORMDATA;

sampler sTex = sampler_state
{
    Texture = (tex);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    
    AddressU = Clamp;
};

struct VS_IN
{
    float2 pos : POSITION;
    float2 tc : TEXCOORD0;
};

struct PS_IN
{
    float4 pos : SV_POSITION;
    float2 tc : TEXCOORD0;
};


float4 backgroundColor : BACKGROUNDCOLOR;
float4 highlightColor  : HIGHLIGHTCOLOR;
float4 selectionColor  : SELECTIONCOLOR;
float4 textColor       : TEXTCOLOR;
float cursorPos        : CURSORPOSITION;
bool cursorVisible     : CURSORVISIBLE;
float seekPos          : SEEKPOSITION;
bool seeking           : SEEKING;
float4 replayGain      : REPLAYGAIN; // album gain, track gain, album peak, track peak
float2 viewportSize    : VIEWPORTSIZE;
bool horizontal        : ORIENTATION;
bool flipped           : FLIPPED;
bool shadePlayed       : SHADEPLAYED;
int trackDuration      : TRACKDURATION; // length of track in seconds


PS_IN VS( VS_IN input )
{
    PS_IN output = (PS_IN)0;

    float2 half_pixel = float2(1,-1) / viewportSize;
    output.pos = float4(input.pos - half_pixel, 0, 1);

    input.tc.y=log(input.tc.y);

    if (horizontal)
    {
        output.tc = float2((input.tc.x + 1.0) / 2.0, ( 1*input.tc.y));
    }
    else
    {
        output.tc = float2((-input.tc.y + 1.0) / 2.0, input.tc.x);
    }

    if (flipped)
        output.tc.x = 1.0 - output.tc.x;

    return output;
}

float4 bar( float pos, float2 tc, float4 fg, float4 bg, float width, bool show )
{
    float dist = abs(pos - tc.x);
    float4 c = (show && dist < width)
        ? lerp(fg, bg, smoothstep(0, width, dist))
        : bg;
    return c;
}

float4 evaluate( float2 tc ) {

    float4 minmaxrms = tex1D(sTex, tc.x);
    minmaxrms.b = 0.3*(minmaxrms.g - 0.5)+(minmaxrms.b - 0.5); //weighted average of peak and avg loudness

    float fullAlphaPos = seeking ? min(cursorPos, seekPos.x) : cursorPos;
    float halfAlphaPos = seeking ? max(cursorPos, seekPos.x) : cursorPos;

    if (abs(tc.y) <= (minmaxrms.b)) { //shade background (outside rms value) based on timestamp
        // Apply selectionColor as a gradient upto the current play position or the mouse if it's more left when seeking.
        // Apply selectionColor as an overlayed gradient upto the position that's more right.

        if (fullAlphaPos > tc.x) {
            // Apply gradient
            return lerp(highlightColor, -highlightColor, -tc.y);
        } else if (halfAlphaPos > tc.x) {
            // Apply overlay gradient
            return lerp(highlightColor, textColor, 0.5);
        } else {
            return textColor;
        }
    } else {        
	bool isEvenMinute = ((tc.x * trackDuration) % 120 >= (60)); // used for the minute markings

        if (shadePlayed) {
            if ((fullAlphaPos > tc.x)) {
                // Apply gradient
                return lerp(textColor - 0.15, backgroundColor - (0.1 * isEvenMinute), 0.5);
            } else if (halfAlphaPos > tc.x) {
                // Apply overlay gradient
                return lerp(textColor, backgroundColor - (0.1 * isEvenMinute), 0.5);
            } else {
                return backgroundColor - (0.05 * isEvenMinute);
            }
        } else {
            return backgroundColor - (0.05 * isEvenMinute);
        }
    }
}

float4 PS( PS_IN input ) : SV_Target
{
    float dx, dy;
    if (horizontal)
    {
        dx = 1/viewportSize.x;
        dy = 1/viewportSize.y;
    }
    else
    {
        dx = 1/viewportSize.y;
        dy = 1/viewportSize.x;
    }

    float4 c0 = evaluate(input.tc);
    if (shadePlayed) {
        c0 = bar(cursorPos, input.tc, selectionColor, c0, 2 * dx, cursorVisible);
        c0 = bar(seekPos,   input.tc, selectionColor, c0, 2 * dx,     seeking      );
    }
    return c0;
}

technique Render9
{
	
    pass
    {
        VertexShader = compile vs_2_0 VS();
        PixelShader = compile ps_2_0 PS(); //change version from ps_2_0 to ps_2_a or ps_3_0 for additional arithmetic instruction slots
    }
}
