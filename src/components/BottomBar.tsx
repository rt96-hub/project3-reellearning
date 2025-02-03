import { Grid2X2, MessageSquare, Heart, User } from "lucide-react";
import { Link } from "react-router-dom";

const BottomBar = () => {
  return (
    <div className="fixed bottom-0 left-0 right-0 h-16 bg-background border-t flex items-center justify-around px-4 z-50">
      <Link to="/home" className="flex flex-col items-center">
        <Grid2X2 className="h-6 w-6" />
        <span className="text-xs mt-1">1</span>
      </Link>
      <Link to="/messages" className="flex flex-col items-center">
        <MessageSquare className="h-6 w-6" />
        <span className="text-xs mt-1">2</span>
      </Link>
      <Link to="/likes" className="flex flex-col items-center">
        <Heart className="h-6 w-6" />
        <span className="text-xs mt-1">3</span>
      </Link>
      <Link to="/profile" className="flex flex-col items-center">
        <User className="h-6 w-6" />
        <span className="text-xs mt-1">4</span>
      </Link>
    </div>
  );
};

export default BottomBar;