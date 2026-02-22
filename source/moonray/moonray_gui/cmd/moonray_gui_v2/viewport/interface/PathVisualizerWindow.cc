// Copyright 2025 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

#include "PathVisualizerWindow.h"

#include "DrawUtil.h"
#include "../Viewport.h"

#include <moonray/rendering/rndr/PathVisualizerManager.h>

namespace moonray_gui_v2 {

void
PathVisualizerWindow::drawEnableButton()
{
    const bool enabled = mManager->isOn();
    const char* buttonText = enabled ? "Disable" : "Enable";
    const ImVec2 buttonSize(60, 30);
    
    if (ImGui::Button(buttonText, buttonSize)) {
        // When clicked, toggle on/off path visualizer
        if (enabled) { mManager->turnOff(); } 
        else         { mManager->turnOn();  }
    }

    if (ImGui::IsItemHovered()) {
        ImGui::SetMouseCursor(ImGuiMouseCursor_Hand);
    }
}

void
PathVisualizerWindow::drawPixelSelector()
{
    // Default to open
    ImGui::SetNextItemOpen(true, ImGuiCond_Once);
    if (ImGui::CollapsingHeader("Pixel Selector")) {
        const int pixelX = static_cast<int>(mManager->getPixelX());
        const int pixelY = static_cast<int>(mManager->getPixelY());

        drawInputInt("Pixel X", pixelX, mMinPixelX, mMaxPixelX, [this](int value) {
            this->mManager->setPixelX(static_cast<uint32_t>(std::max(0, value)), /*update*/ true);
        });

        drawInputInt("Pixel Y", pixelY, mMinPixelY, mMaxPixelY, [this](int value) {
            this->mManager->setPixelY(static_cast<uint32_t>(std::max(0, value)), /*update*/ true);
        });
    }
    if (ImGui::IsItemHovered()) { ImGui::SetMouseCursor(ImGuiMouseCursor_Hand); }
}

void
PathVisualizerWindow::drawSamplingSettingsMenu()
{
    // Default to open
    ImGui::SetNextItemOpen(true, ImGuiCond_Once);
    if (ImGui::CollapsingHeader("Sampling Settings")) {
        bool useSceneSamples = mManager->getUseSceneSamples();

        if (ImGui::Checkbox("Use Scene Sampling Settings", &useSceneSamples)) {
            mManager->setUseSceneSamples(useSceneSamples, /*update*/ true);
        }
        
        // Disable other sampling settings if useSceneSamples is checked
        ImGui::BeginDisabled(useSceneSamples);

        // -------------------- Pixel Samples Input --------------------------- //
        drawInputInt("Pixel Samples", mManager->getPixelSamples(), mMinPixelSamples, mMaxPixelSamples, [this](int value) {
            this->mManager->setPixelSamples(value, /*update*/ true);
        });
        
        // -------------------- Light Samples Input --------------------------- //
        drawInputInt("Light Samples", mManager->getLightSamples(), mMinLightSamples, mMaxLightSamples, [this](int value) {
            this->mManager->setLightSamples(value, /*update*/ true);
        });
        
        // -------------------- BSDF Samples Input --------------------------- //
        drawInputInt("BSDF  Samples", mManager->getBsdfSamples(), mMinBsdfSamples, mMaxBsdfSamples, [this](int value) {
            this->mManager->setBsdfSamples(value, /*update*/ true);
        });

        ImGui::EndDisabled();
    }
    if (ImGui::IsItemHovered()) { ImGui::SetMouseCursor(ImGuiMouseCursor_Hand);}
}

void 
PathVisualizerWindow::drawMaxDepthMenu()
{
    // Default to open
    ImGui::SetNextItemOpen(true, ImGuiCond_Once);
    if (ImGui::CollapsingHeader("Max Depth")) {

        drawInputInt("Max Depth", mManager->getMaxDepth(), mMinMaxDepth, mMaxMaxDepth, [this](int value) {
            this->mManager->setMaxDepth(value, /*update*/ true);
        });
    }
    if (ImGui::IsItemHovered()) { ImGui::SetMouseCursor(ImGuiMouseCursor_Hand); }
}

void
PathVisualizerWindow::drawVisibilityTogglesMenu()
{
    // Default to open
    ImGui::SetNextItemOpen(true, ImGuiCond_Once);
    if (ImGui::CollapsingHeader("Visibility Toggles")) {
        bool showDiffuse = mManager->getShowDiffuseRays();
        bool showSpecular = mManager->getShowSpecularRays();
        bool showBsdf = mManager->getShowBsdfSamples();
        bool showLight = mManager->getShowLightSamples();
        
        if (ImGui::Checkbox("Diffuse Rays", &showDiffuse)) {
            mManager->setShowDiffuseRays(showDiffuse);
        }
        if (ImGui::Checkbox("Specular Rays", &showSpecular)) {
            mManager->setShowSpecularRays(showSpecular);
        }
        if (ImGui::Checkbox("Bsdf Samples", &showBsdf)) {
            mManager->setShowBsdfSamples(showBsdf);
        }
        if (ImGui::Checkbox("Light Samples", &showLight)) {
            mManager->setShowLightSamples(showLight);
        }
    }
    if (ImGui::IsItemHovered()) { ImGui::SetMouseCursor(ImGuiMouseCursor_Hand); }
}

void
PathVisualizerWindow::drawStyleMenu()
{
    // Default to open
    ImGui::SetNextItemOpen(true, ImGuiCond_Once);
    if (ImGui::CollapsingHeader("Style Options")) {
        // Line width control
        int roundedLineWidth = static_cast<uint32_t>(mManager->getLineWidth() + 0.5f);
        drawInputInt("Line Width", roundedLineWidth, mMinLineWidth, mMaxLineWidth, [this](int value) {
            this->mManager->setLineWidth(static_cast<float>(value));
        });
        // Hidden line opacity
        drawSliderFloat("Hidden Line Opacity", mManager->getHiddenLineOpacity(), 0.0f, 1.0f, [this](float value) {
            this->mManager->setHiddenLineOpacity(value);
        });

        // Color pickers for different ray types
        drawColorEdit("Diffuse Ray Color", mManager->getDiffuseRayColor(), [this](scene_rdl2::math::Color color) {
            this->mManager->setDiffuseRayColor(color);
        });
        drawColorEdit("Specular Ray Color", mManager->getSpecularRayColor(), [this](scene_rdl2::math::Color color) {
            this->mManager->setSpecularRayColor(color);
        });
        drawColorEdit("BSDF Sample Color", mManager->getBsdfSampleColor(), [this](scene_rdl2::math::Color color) {
            this->mManager->setBsdfSampleColor(color);
        });
        drawColorEdit("Light Sample Color", mManager->getLightSampleColor(), [this](scene_rdl2::math::Color color) {
            this->mManager->setLightSampleColor(color);
        });
        drawColorEdit("Camera Ray Color", mManager->getCameraRayColor(), [this](scene_rdl2::math::Color color) {
            this->mManager->setCameraRayColor(color);
        });
    }
    if (ImGui::IsItemHovered()) { ImGui::SetMouseCursor(ImGuiMouseCursor_Hand); }
}

void
PathVisualizerWindow::configureWindow(const ImVec2& dockOffset) const
{
    // Establish size and position
    ImGuiViewport* imguiViewport = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(ImVec2(imguiViewport->Size.x - mWidth - dockOffset.x, 0));
    ImGui::SetNextWindowSize(ImVec2(mWidth, imguiViewport->Size.y));

    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(mWindowPadding, mWindowPadding));
    ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(ImGui::GetStyle().ItemSpacing.x, mItemSpacing));
}

void
PathVisualizerWindow::draw(Viewport* viewport, const ImVec2& currentPixel, const ImVec2& dockOffset)
{
    if (!mOpen) { return; }

    // If path visualizer manager doesn't exist, we can't
    // perform any of the actions in the UI. Try
    // to retrieve it from the viewport.
    if (!mManager) {
        mManager = viewport->getPathVisualizerManager();
        if (!mManager) { return; }
    }

    configureWindow(dockOffset);

    // Create window
    ImGui::Begin("Path Visualizer", &mOpen, ImGuiWindowFlags_NoMove | 
                                            ImGuiWindowFlags_NoResize |
                                            ImGuiWindowFlags_NoCollapse);
    // Create "on/off" button
    drawEnableButton();
    // Create pixel selector
    drawPixelSelector();
    // Create sampling settings menu
    drawSamplingSettingsMenu();
    // Create max depth menu
    drawMaxDepthMenu();
    // Create visibility toggles menu
    drawVisibilityTogglesMenu();
    // Create style options menu
    drawStyleMenu();

    ImGui::End();
    ImGui::PopStyleVar(2);
}

} // namespace moonray_gui_v2
