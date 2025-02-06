// Users Collection
users: {
  userId: {
    createdAt: Timestamp,
    email: String,
    phone: String,
    profile: {
      displayName: String,
      avatarUrl: String,
      biography: String,
    },
    uid: String,
  }
}



// Videos Collection
videos: {
  videoId: {
    creator: Reference,  // Reference to users collection
    metadata: {
      title: String,
      description: String,
      thumbnailUrl: String,
      videoUrl: String,
      duration: Number,
      uploadedAt: Timestamp,
      updatedAt: Timestamp
    },
    classification: {
      // Creator-provided elements
      explicit: {
        hashtags: Array<String>,
        description: String,
        targetAudience: String,     // Free-form text
        prerequisites: Array<String> // Video IDs that help understand this content
      },
    },
    engagement: {
      views: Number,
      likes: Number,
      bookmarks: Number,
      shares: Number,
      completionRate: Number,
      averageWatchTime: Number
    }
  }
}

// Video Comments Collection
videoComments: {
  commentId: {
    videoId: Reference,
    author: Reference,      // Reference to users collection
    content: {
      text: String,
      timestamp: Number,    // Video timestamp this comment refers to
      attachments: Array<{
        type: String,       // 'image', 'link', 'equation'
        content: String,    // URL or LaTeX string for equations
        preview: String     // Preview text for links
      }>
    },
    likeCount: Number,
    metadata: {
      createdAt: Timestamp,
      updatedAt: Timestamp,
      isEdited: Boolean,
      isPinned: Boolean,    // For important explanations or answers
      isResolved: Boolean   // For question-type comments
    },
  }
}


// Comment Likes Collection
commentLikes: {
  userId_commentId: {
    userId: Reference,
    commentId: Reference,
    likedAt: Timestamp
  }
}


// Comment Replies Collection
commentReplies: {
  replyId: {
    commentId: Reference,
    author: Reference,
    content: {
      text: String,
      attachments: Array<{
        type: String,
        content: String,
        preview: String
      }>
    },
    metadata: {
      createdAt: Timestamp,
      updatedAt: Timestamp,
      isEdited: Boolean,
      isAcceptedAnswer: Boolean  // For marking best explanations
    },
  }
}

// Direct Messages Collection
directMessages: {
  chatId: {
    participants: Array<Reference>,
    metadata: {
      createdAt: Timestamp,
      lastMessage: Timestamp,
      isGroupChat: Boolean,
      name: String,           // For group chats
      type: String           // 'study_group', 'mentoring', 'general'
    },
    messages: Array<{
      author: Reference,
      content: {
        text: String,
        attachments: Array<{
          type: String,
          content: String,
          preview: String
        }>,
        sharedContent: {     // For sharing educational content
          videoId: Reference,
          timestamp: Number,
          note: String
        }
      },
      metadata: {
        sentAt: Timestamp,
        readBy: Array<Reference>,
        edited: Boolean
      }
    }>,
  }
}

// Class Messages Collection
classMessages: {
  messageId: {
    classId: Reference,
    author: Reference,
    type: String,           // 'announcement', 'discussion', 'question', 'resource'
    content: {
      text: String,
      attachments: Array<{
        type: String,
        content: String,
        preview: String
      }>,
      relatedVideos: Array<Reference>
    },
    metadata: {
      createdAt: Timestamp,
      updatedAt: Timestamp,
      isPinned: Boolean,
      isAnnouncement: Boolean,
    },
  }
}

// Class Message Replies Collection
classMessageReplies: {
  replyId: {
    messageId: Reference,
    author: Reference,
    content: {
      text: String,
      attachments: Array<{
        type: String,
        content: String,
        preview: String
      }>
    },
    metadata: {
      createdAt: Timestamp,
      updatedAt: Timestamp,
      isEdited: Boolean,
      isHighlighted: Boolean  // For particularly helpful responses
    },
    context: {
      responseType: String,   // 'answer', 'question', 'discussion'
      helpfulCount: Number,
      isVerified: Boolean    // For answers verified by class curator
    }
  }
}


classes: {
  classId: {
    creator: Reference,  // Reference to users collection
    title: String,
    description: String,
    createdAt: Timestamp,
    updatedAt: Timestamp,
    isPublic: Boolean,
    thumbnail: String,
    memberCount: Number,
  }
}

// Class Activity Collection - Tracks curator's feed-training actions
classActivity: {
  classId_videoId: {
    classId: Reference,
    videoId: Reference,
    curatorActions: Array<{
      action: String,         // 'like', 'understand', 'exclude', etc.
      timestamp: Timestamp,
      context: {
        previousVideos: Array<String>,  // What led to this video
        conceptualState: Map<String, Number>  // Class's conceptual focus at time
      }
    }>,
  }
}

// Class Membership Collection - Tracks follower experiences
classMembership: {
  userId_classId: {
    userId: Reference,
    classId: Reference,
    joinedAt: Timestamp,
    role: String,  // 'curator', 'follower'
  }
}



userBookmarks: {
  userId_videoId: {
    userId: Reference,
    videoId: Reference,
    classId: Array<Reference>,  // Optional, if bookmarked within a class, then classId may be appended to the array
    addedAt: Timestamp

  }
}

userLikes: {
  userId_videoId: {
    userId: Reference,
    videoId: Reference,
    classId: Array<Reference>,  // Optional, if liked within a class context, can be updated to append new classId
    likedAt: Timestamp
  }
}

// Video Comprehension Collection
videoComprehension: {
  userId_videoId: {
    userId: Reference,
    videoId: Reference,
    classId: Array<Reference>,  // Optional, if watched within a class, then classId may be appended to the array
    comprehensionLevel: String,  // 'not_understood', 'partially_understood', 'fully_understood'
    assessedAt: Timestamp,
    updatedAt: Timestamp,
    watchCount: Number,  // How many times they've watched the video
    nextRecommendedReview: Timestamp  // For spaced repetition learning
  }
}


