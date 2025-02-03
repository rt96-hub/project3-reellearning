import { useState } from "react";
import { MessageSquare, Heart, Bookmark, User } from "lucide-react";
import BottomBar from "@/components/BottomBar";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";

const Index = () => {
  const [isLiked, setIsLiked] = useState(false);
  const [isBookmarked, setIsBookmarked] = useState(false);
  const [showFullDescription, setShowFullDescription] = useState(false);

  const description = "This is an amazing video showing the beautiful sunset at the beach. The waves are crashing against the shore while seagulls fly overhead, creating a perfect moment of peace and tranquility.";

  return (
    <div className="min-h-screen bg-black">
      {/* Video Container */}
      <div className="relative h-screen w-full bg-gray-900">
        <img 
          src="/placeholder.svg" 
          alt="Video placeholder" 
          className="h-full w-full object-cover"
        />
        
        {/* Video Info Overlay */}
        <div className="absolute bottom-20 left-0 right-0 p-4 text-white">
          <div className="flex items-start gap-3 mb-4">
            <Avatar className="h-10 w-10 cursor-pointer">
              <AvatarImage src="/placeholder.svg" />
              <AvatarFallback>UN</AvatarFallback>
            </Avatar>
            <div>
              <h3 className="font-semibold cursor-pointer">@username</h3>
              <p 
                className={`text-sm mt-1 ${!showFullDescription && "line-clamp-2"}`}
                onClick={() => setShowFullDescription(!showFullDescription)}
              >
                {description}
              </p>
            </div>
          </div>
        </div>

        {/* Right Side Actions */}
        <div className="absolute right-4 bottom-32 flex flex-col gap-6">
          <Button 
            variant="ghost" 
            size="icon" 
            className="rounded-full bg-gray-800/50 text-white hover:bg-gray-700/50"
            onClick={() => setIsLiked(!isLiked)}
          >
            <Heart className={`h-6 w-6 ${isLiked ? "fill-red-500 text-red-500" : ""}`} />
          </Button>
          
          <Button 
            variant="ghost" 
            size="icon" 
            className="rounded-full bg-gray-800/50 text-white hover:bg-gray-700/50"
          >
            <MessageSquare className="h-6 w-6" />
          </Button>
          
          <Button 
            variant="ghost" 
            size="icon" 
            className="rounded-full bg-gray-800/50 text-white hover:bg-gray-700/50"
            onClick={() => setIsBookmarked(!isBookmarked)}
          >
            <Bookmark className={`h-6 w-6 ${isBookmarked ? "fill-white" : ""}`} />
          </Button>
        </div>
      </div>

      <BottomBar />
    </div>
  );
};

export default Index;