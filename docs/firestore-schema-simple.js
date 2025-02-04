// Users Collection
users: {
  userId: {
    profile: {
      displayName: String,
      email: String,
      avatarUrl: String,
      biography: String,
      joinedAt: Timestamp,
      lastActive: Timestamp
    },
    }
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
    metadata: {
      createdAt: Timestamp,
      updatedAt: Timestamp,
      isEdited: Boolean,
      isPinned: Boolean,    // For important explanations or answers
      isResolved: Boolean   // For question-type comments
    },
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
    metadata: {
      title: String,
      description: String,
      createdAt: Timestamp,
      updatedAt: Timestamp,
      isPublic: Boolean,
      thumbnail: String
    },
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
    lastActive: Timestamp,
    role: String,  // 'creator', 'follower'
    personalizedState: {
      conceptualProgress: Map<String, {
        exposure: Number,
        understanding: Number,
        lastEncounter: Timestamp
      }>,
      currentDifficulty: Number,
      recommendationContext: {
        lastVideos: Array<String>,
        strongestConcepts: Array<String>,
        challengingConcepts: Array<String>
      }
    },
    engagementMetrics: {
      videosWatched: Number,
      averageCompletion: Number,
      understandingRate: Number,
      streakDays: Number
    }
  }
}



userBookmarks: {
  userId_videoId: {
    userId: Reference,
    videoId: Reference,
    classId: Reference,  // Optional, if bookmarked within a class
    addedAt: Timestamp,
    notes: String
  }
}

userLikes: {
  userId_videoId: {
    userId: Reference,
    videoId: Reference,
    classId: Reference,  // Optional, if liked within a class context
    likedAt: Timestamp
  }
}

// Video Comprehension Collection
videoComprehension: {
  userId_videoId: {
    userId: Reference,
    videoId: Reference,
    classId: Reference,  // Optional, if watched within a class
    comprehensionLevel: String,  // 'not_understood', 'partially_understood', 'fully_understood'
    assessedAt: Timestamp,
    updatedAt: Timestamp,
    watchCount: Number,  // How many times they've watched the video
    difficulties: {
      timestamps: Array<Number>,  // Video timestamps where user marked difficulty
      topics: Array<String>      // Specific topics user found challenging
    },
    notes: String,  // Personal notes about understanding
    nextRecommendedReview: Timestamp  // For spaced repetition learning
  }
}


