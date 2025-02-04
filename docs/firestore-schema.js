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
    preferences: {
      contentLanguages: Array<String>,
      learningStyle: String,          // 'visual', 'auditory', 'reading', 'kinesthetic'
      pacePreference: String,         // 'slower', 'moderate', 'faster'
      notificationSettings: {
        classUpdates: Boolean,
        newContent: Boolean,
        learningReminders: Boolean
      }
    },
    learningMetrics: {
      comprehensionDistribution: {
        notUnderstood: Number,     
        partiallyUnderstood: Number,
        fullyUnderstood: Number
      },
      conceptualProgress: Map<String, {  // Dynamic mapping of concepts to progress
        exposure: Number,            // How many times encountered
        demonstratedMastery: Number, // Success rate in related content
        lastEncounter: Timestamp,
        confidence: Number           // System's confidence in user's understanding
      }>,
      learningStreak: {
        currentStreak: Number,
        longestStreak: Number,
        lastActivity: Timestamp
      }
    },
    stats: {
      totalVideosWatched: Number,
      totalWatchTime: Number,
      averageCompletionRate: Number,
      totalClassesCreated: Number,
      totalClassesJoined: Number,
      totalFollowers: Number,
      contributionMetrics: {
        videosCreated: Number,
        totalViews: Number,
        averageEngagement: Number,
        helpfulnessScore: Number     // Based on user feedback
      }
    },
    contentHistory: {
      recentlyWatched: Array<{
        videoId: Reference,
        timestamp: Timestamp,
        completionRate: Number,
        comprehensionLevel: String
      }>,
      recentlyCreated: Array<{
        videoId: Reference,
        timestamp: Timestamp,
        performance: {
          views: Number,
          completionRate: Number,
          helpfulnessScore: Number
        }
      }>
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
      
      // System-detected classification
      detected: {
        transcription: String,
        detectedConcepts: Array<{
          concept: String,
          confidence: Number,
          timestamp: Number    // When in the video this appears
        }>,
        conceptualRelationships: Array<{
          conceptA: String,
          conceptB: String,
          relationshipType: String  // 'builds_on', 'introduces', 'references'
        }>,
        teachingElements: Array<{
          type: String,            // 'visualization', 'explanation', 'practice', 'review'
          timestamp: Number,
          duration: Number
        }>,
        complexity: {
          conceptDensity: Number,      // How many new concepts per minute
          prerequisiteDepth: Number,    // How much background knowledge needed
          explanationClarity: Number    // Based on language complexity and pace
        }
      },
      
      // Emergent classification from user behavior
      learned: {
        conceptualClusters: Array<{
          relatedConcepts: Array<String>,
          strength: Number,           // How strongly these concepts relate
          emergenceTimestamp: Timestamp // When this cluster was first detected
        }>,
        learningPathways: Array<{
          prerequisiteVideos: Array<String>,
          successorVideos: Array<String>,
          pathStrength: Number        // How often this path leads to success
        }>,
        audienceSegments: Array<{
          userCharacteristics: Map<String, Number>, // Learned attributes of successful viewers
          comprehensionRate: Number,
          engagementScore: Number
        }>,
        teachingEffectiveness: {
          conceptRetention: Number,    // Based on performance in related content
          skillTransfer: Number,       // Success in applying concepts elsewhere
          prerequisiteAlignment: Number // How well it builds on required knowledge
        }
      }
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
    context: {
      questionType: String,  // 'concept_question', 'clarification', 'discussion', etc.
      relatedConcepts: Array<String>,
      difficulty: String     // Help categorize the complexity of questions/answers
    },
    engagement: {
      helpful: Number,       // Upvotes specifically for educational value
      replies: Number,
      views: Number
    },
    flags: {
      reported: Boolean,
      moderationStatus: String,
      lastReviewedAt: Timestamp
    }
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
    context: {
      answerType: String,        // 'explanation', 'follow_up', 'clarification'
      confidence: Number,        // How sure the responder is about their answer
      references: Array<String>  // Links to related videos or external resources
    },
    engagement: {
      helpful: Number,
      endorsed: Array<Reference>  // Educators who've verified this answer
    }
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
    studyContext: {          // Optional, for study-focused chats
      topics: Array<String>,
      difficulty: String,
      goals: String,
      schedule: {
        frequency: String,
        nextSession: Timestamp
      }
    }
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
      visibility: String    // 'all_members', 'active_members', 'moderators'
    },
    engagement: {
      views: Number,
      replies: Number,
      saves: Number
    },
    educational: {
      concepts: Array<String>,
      difficulty: String,
      learningObjective: String,
      resourceType: String  // 'practice_problem', 'explanation', 'discussion_prompt'
    }
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
    algorithmicProfile: {
      conceptualFocus: Array<{
        concept: String,
        weight: Number,        // How strongly this concept should influence recommendations
        addedAt: Timestamp    // When this concept became significant in the class
      }>,
      difficultyRange: {
        min: Number,
        max: Number,
        targetLevel: Number,   // Where most content should cluster
        adaptiveRange: Boolean // Whether difficulty should adjust based on user comprehension
      },
      contentPreferences: {
        preferredDuration: {
          min: Number,
          max: Number
        },
        teachingStyles: Array<{
          style: String,      // 'visual', 'theoretical', 'practical', etc.
          weight: Number      // Preference strength for this style
        }>,
        prerequisiteStrength: Number  // How strict to be about knowledge dependencies
      },
      excludedVideos: Array<String>  // Videos explicitly marked as not fitting the class
    },
    curatorActivity: {
      lastCurationAction: Timestamp,
      recentActions: Array<{
        actionType: String,   // 'like', 'comprehension_marked', 'excluded', etc.
        videoId: String,
        timestamp: Timestamp,
        impact: Number        // How much this action influenced the algorithm
      }>,
      curationStrength: Number  // Measure of how actively curator shapes the feed
    },
    stats: {
      followerCount: Number,
      activeFollowers: Number,  // Followers active in last 30 days
      averageEngagement: {
        watchTime: Number,
        completionRate: Number,
        understandingRate: Number
      },
      conceptualProgress: {
        conceptsCovered: Number,
        averageDepth: Number,   // How deeply concepts are explored
        conceptualCoherence: Number  // How well videos connect conceptually
      }
    }
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
    algorithmicImpact: {
      conceptualInfluence: Map<String, Number>,  // How this video shaped class focus
      difficultyCalibration: Number,    // How it influenced difficulty targeting
      stylistic Impact: Array<{
        style: String,
        influence: Number
      }>
    },
    followerEngagement: {
      totalViews: Number,
      completionRate: Number,
      understandingRate: Number,
      feedbackScore: Number
    }
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

// Class Progress Collection
classProgress: {
  userId_classId: {
    userId: Reference,
    classId: Reference,
    overallProgress: Number,  // 0-100 percentage
    videosProgress: {
      videoId: {
        comprehensionLevel: String,
        lastWatched: Timestamp,
        watchCount: Number,
        isComplete: Boolean
      }
    },
    startedAt: Timestamp,
    lastActivity: Timestamp,
    estimatedCompletionDate: Timestamp,
    currentDifficulty: String  // For adaptive learning paths
  }
}
