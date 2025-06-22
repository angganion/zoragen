'use client'

import React, { useState, useRef } from 'react';
import { Download, Share2, Settings, Sparkles, Image, Zap, Wand2 } from 'lucide-react';

interface GeneratedImage {
  id: string;
  url: string;
  prompt: string;
  style: string;
  timestamp: Date;
}

const ZoragenCreate: React.FC = () => {
  const [prompt, setPrompt] = useState('');
  const [selectedStyle, setSelectedStyle] = useState('digital-art');
  const [isGenerating, setIsGenerating] = useState(false);
  const [generatedImages, setGeneratedImages] = useState<GeneratedImage[]>([]);
  const [sourceImage, setSourceImage] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const styles = [
    { id: 'digital-art', name: 'Digital Art', gradient: 'from-green-400 to-teal-400' },
    { id: 'photorealistic', name: 'Photorealistic', gradient: 'from-sky-400 to-cyan-400' },
    { id: 'anime', name: 'Anime', gradient: 'from-emerald-400 to-lime-400' },
    { id: 'oil-painting', name: 'Oil Painting', gradient: 'from-amber-400 to-orange-400' },
    { id: 'cyberpunk', name: 'Cyberpunk', gradient: 'from-teal-400 to-sky-400' },
    { id: 'minimalist', name: 'Minimalist', gradient: 'from-slate-400 to-gray-500' }
  ];

  const handleGenerate = async () => {
    if (!prompt.trim()) return;
    
    setIsGenerating(true);
    
    // Simulasi API call ke Xora SDK
    setTimeout(() => {
      const newImage: GeneratedImage = {
        id: Date.now().toString(),
        url: `https://picsum.photos/512/512?random=${Date.now()}`,
        prompt: prompt,
        style: selectedStyle,
        timestamp: new Date()
      };
      
      setGeneratedImages(prev => [newImage, ...prev]);
      setIsGenerating(false);
    }, 3000);
  };

  const handleImageUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        setSourceImage(e.target?.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const removeSourceImage = () => {
    setSourceImage(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-black to-green-900 text-white">
      {/* Header */}
      <header className="border-b border-gray-700/80 bg-black/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-r from-green-500 to-lime-400 rounded-xl flex items-center justify-center">
                <Sparkles className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-100">Zoragen</h1>
                <p className="text-sm text-gray-400">Create. Remix. Own.</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <button className="p-2 text-gray-400 hover:text-white transition-colors">
                <Settings className="w-5 h-5" />
              </button>
              <div className="w-8 h-8 bg-gradient-to-r from-green-300 to-lime-300 rounded-full"></div>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-6 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Left Panel - Controls */}
          <div>
            <div className="bg-gray-900/60 backdrop-blur-xl rounded-2xl border border-gray-700/80 p-6">
              {/* Prompt Input */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Describe your vision
                </label>
                <textarea
                  value={prompt}
                  onChange={(e) => setPrompt(e.target.value)}
                  placeholder="A majestic dragon flying through neon-lit cyberpunk city at sunset..."
                  className="w-full h-32 bg-gray-800/50 border border-gray-600/50 rounded-xl px-4 py-3 text-gray-100 placeholder-gray-500 focus:outline-none focus:border-green-500 focus:ring-2 focus:ring-green-500/20 resize-none"
                />
              </div>

              {/* Source Image Upload */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Source Image (Optional)
                </label>
                {!sourceImage ? (
                  <div
                    onClick={() => fileInputRef.current?.click()}
                    className="border-2 border-dashed border-gray-600/70 rounded-xl p-6 text-center cursor-pointer hover:border-green-400 transition-colors"
                  >
                    <Image className="w-8 h-8 text-green-500 mx-auto mb-2" />
                    <p className="text-sm text-gray-400 mb-1">Click to upload reference image</p>
                    <p className="text-xs text-gray-500">PNG, JPG up to 10MB</p>
                  </div>
                ) : (
                  <div className="relative">
                    <div className="aspect-video bg-gray-800/50 rounded-xl overflow-hidden border border-gray-700/50">
                      <img
                        src={sourceImage}
                        alt="Source reference"
                        className="w-full h-full object-cover"
                      />
                    </div>
                    <button
                      onClick={removeSourceImage}
                      className="absolute top-2 right-2 p-1 bg-red-500 text-white rounded-full hover:bg-red-600 transition-colors"
                    >
                      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                )}
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleImageUpload}
                  className="hidden"
                />
              </div>

              {/* Style Selection */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-300 mb-3">
                  Art Style
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {styles.map((style) => (
                    <button
                      key={style.id}
                      onClick={() => setSelectedStyle(style.id)}
                      className={`p-3 rounded-xl border transition-all ${
                        selectedStyle === style.id
                          ? 'border-green-500 bg-green-500/10'
                          : 'border-gray-700/70 bg-gray-800/20 hover:border-green-400/50'
                      }`}
                    >
                      <div className={`w-full h-6 bg-gradient-to-r ${style.gradient} rounded-lg mb-2`}></div>
                      <span className="text-xs text-gray-300">{style.name}</span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Generate Button */}
              <button
                onClick={handleGenerate}
                disabled={!prompt.trim() || isGenerating}
                className="w-full bg-green-500 text-white py-4 rounded-xl font-semibold disabled:opacity-50 disabled:cursor-not-allowed hover:bg-green-600 hover:shadow-lg hover:shadow-green-500/25 transition-all"
              >
                {isGenerating ? (
                  <div className="flex items-center justify-center">
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></div>
                    Creating Magic...
                  </div>
                ) : (
                  <div className="flex items-center justify-center">
                    <Zap className="w-5 h-5 mr-2" />
                    {sourceImage ? 'Transform Image' : 'Generate Art'}
                  </div>
                )}
              </button>
            </div>
          </div>

          {/* Right Panel - Generated Images */}
          <div>
            <div className="bg-gray-900/60 backdrop-blur-xl rounded-2xl border border-gray-700/80 p-6">
              <h2 className="text-xl font-semibold text-gray-100 mb-6">Your Creations</h2>
              
              {generatedImages.length === 0 ? (
                <div className="text-center py-16">
                  <Sparkles className="w-16 h-16 text-green-500 mx-auto mb-4" />
                  <h3 className="text-xl font-medium text-gray-100 mb-2">Start Creating</h3>
                  <p className="text-gray-400">Your AI-generated masterpieces will appear here</p>
                </div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {generatedImages.map((image) => (
                    <div key={image.id} className="group relative">
                      <div className="aspect-square rounded-xl overflow-hidden bg-gray-800/50 border border-gray-700/50">
                        <img
                          src={image.url}
                          alt={image.prompt}
                          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                        />
                      </div>
                      
                      {/* Overlay */}
                      <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity rounded-xl flex items-center justify-center">
                        <div className="flex space-x-3">
                          <button className="p-3 bg-green-500 text-white rounded-xl hover:bg-green-600 transition-colors">
                            <Download className="w-5 h-5" />
                          </button>
                          <button className="p-3 bg-gray-500 text-white rounded-xl hover:bg-gray-600 transition-colors">
                            <Share2 className="w-5 h-5" />
                          </button>
                          <button className="p-3 bg-gray-500 text-white rounded-xl hover:bg-gray-600 transition-colors">
                            <Wand2 className="w-5 h-5" />
                          </button>
                        </div>
                      </div>

                      {/* Info */}
                      <div className="mt-3">
                        <p className="text-sm text-gray-300 line-clamp-2">{image.prompt}</p>
                        <p className="text-xs text-green-600 mt-1">
                          {styles.find(s => s.id === image.style)?.name} • {image.timestamp.toLocaleTimeString()}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ZoragenCreate;