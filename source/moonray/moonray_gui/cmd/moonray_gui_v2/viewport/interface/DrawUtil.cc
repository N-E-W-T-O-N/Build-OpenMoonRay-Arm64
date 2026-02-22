// Copyright 2025 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

#include "DrawUtil.h"

namespace moonray_gui_v2 {

// Draw an integer input box with a label, and a callback for when the value changes
void drawInputInt(const std::string& label, int value, const int min, const int max, 
                  const std::function<void(int)>& callback)
{
    const std::string text = label + ": ";
    const ImVec2 textSize = ImGui::CalcTextSize(text.c_str());
    // Calculate the width needed for the input box
    // Get the space available, and subtract the text size and 5px padding
    const int remainingWidth = ImGui::GetContentRegionAvail().x - textSize.x - 5;

    // ------- Draw the label --------
    ImGui::Text("%s", text.c_str());
    ImGui::SameLine();

    // ------- Draw the input box --------
    ImGui::SetNextItemWidth(remainingWidth);
    const std::string id = "##" + label;
    if (ImGui::InputInt(id.c_str(), &value, min, max)) {
        callback(value);
    }
}

// Draw a slider with a label to the left
void drawSliderFloat(const std::string& label, float value, const float min, const float max, 
                  const std::function<void(float)>& callback)
{
    const std::string text = label + ": ";
    const ImVec2 textSize = ImGui::CalcTextSize(text.c_str());
    // Calculate the width needed for the input box
    // Get the space available, and subtract the text size and 5px padding
    const int remainingWidth = ImGui::GetContentRegionAvail().x - textSize.x - 5;

    // ------- Draw the label --------
    ImGui::Text("%s", text.c_str());
    ImGui::SameLine();

    // ------- Draw the input box --------
    ImGui::SetNextItemWidth(remainingWidth);
    const std::string id = "##" + label;
    if (ImGui::SliderFloat(id.c_str(), &value, min, max)) {
        callback(value);
    }
}

// Draw a color edit with a label, and a callback for when the value changes
void drawColorEdit(const std::string& label, const scene_rdl2::math::Color& color, 
                   const std::function<void(scene_rdl2::math::Color)>& callback)
{
    float colorArray[3] = {color.r, color.g, color.b};
    if (ImGui::ColorEdit3(label.c_str(), colorArray, ImGuiColorEditFlags_NoInputs)) {
        callback(scene_rdl2::math::Color(colorArray[0], colorArray[1], colorArray[2]));
    }
    if (ImGui::IsItemHovered()) { ImGui::SetMouseCursor(ImGuiMouseCursor_Hand); }
}

} // end namespace moonray_gui_v2