#version 330
in vec2 fragTexCoord;
out vec4 finalColor;

uniform sampler2D texture0;
uniform vec3 color;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    if (texelColor.r == 1.0) {
        finalColor = vec4(color, 1.0);
    } else {
        finalColor = texelColor;
    }
}