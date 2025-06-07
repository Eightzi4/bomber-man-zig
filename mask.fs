#version 330
in vec2 fragTexCoord;
out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 color;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    if (texelColor.r == 1.0) {
        finalColor = color;
    } else {
        finalColor = texelColor;
    }
}