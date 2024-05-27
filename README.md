# Ai Boom
Batch generate 3D models powered fully by AI.

[![YouTube](http://i.ytimg.com/vi/fBCc3okDYe8/hqdefault.jpg)](https://www.youtube.com/watch?v=fBCc3okDYe8)

## Features
1. Batch geneate 3D models with just one prompt.
2. Cross-platform, powered by Godot 4, so it supports Windows/MacOS/Linux.

## Requirements
1. OpenAI API key, get it here https://platform.openai.com.
2. Tripo API key, get it here https://platform.tripo3d.ai.

## How it works
1. Generate an image via dall-e-3.
2. Feed the image to gpt4o to generate descriptions for all objects.
3. Feed the descriptions to Tripo to genreate 3d models.

## How to use
1. Set openai API key, tripo API key and a valid directory to store all generated 3D models.
2. Wirte a prompt and press "Generate" to start.
3. Press and drag left mouse button to rotate all models.
4. Left mouse button click model to select.
5. Press and drag middle mouse button to pan.
6. Mouse wheel to zoom in and out.
7. "x" to delete selected models.
8. "r" to re-generate 3D models for selected.
