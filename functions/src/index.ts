import {
  onCall,
  HttpsError,
} from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

// Gemini 2.5 Flash Image - Google's image generation model
// Get your API key from: https://aistudio.google.com/app/apikey
const geminiApiKey = defineSecret("GEMINI_API_KEY");

type RemixStatus = "idle" | "generating" | "completed" | "error";

interface RemixDoc {
  userId: string;
  originalImagePath: string;
  generatedImagePaths?: string[];
  status: RemixStatus;
  errorMessage?: string | null;
  createdAt: FirebaseFirestore.Timestamp;
}

export const generateImages = onCall(
  {
    region: "us-central1",
    invoker: "private",
    secrets: [geminiApiKey],
    timeoutSeconds: 540, // 9 minutes max for image generation
    memory: "1GiB", // Increase memory for image processing
    maxInstances: 10, // Limit concurrent instances to control costs
  },
  async (request) => {
    console.log("generateImages called, auth =", request.auth);

    const remixId = request.data?.remixId;
    if (!remixId) {
      throw new HttpsError("invalid-argument", "remixId is required.");
    }

    // Enhanced authentication check
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      console.error("Unauthenticated request attempt");
      throw new HttpsError("unauthenticated", "User must be authenticated.");
    }

    // Rate limiting check - prevent abuse
    const now = Date.now();
    const userRequestsRef = db.collection("user_requests").doc(callerUid);
    const userRequestsDoc = await userRequestsRef.get();
    
    if (userRequestsDoc.exists) {
      const data = userRequestsDoc.data();
      const lastRequest = data?.lastRequest || 0;
      const requestCount = data?.requestCount || 0;
      const resetTime = data?.resetTime || 0;
      const lastRequestSuccess = data?.lastRequestSuccess !== false;
      
      // Reset counter every hour
      if (now > resetTime) {
        await userRequestsRef.set({
          lastRequest: now,
          requestCount: 1,
          resetTime: now + (60 * 60 * 1000), // 1 hour from now
          lastRequestSuccess: null, // Will be updated after processing
        });
      } else {
        // Check rate limits
        if (requestCount >= 15) { // Max 15 requests per hour (increased)
          throw new HttpsError(
            "resource-exhausted",
            "Rate limit exceeded. Maximum 15 generations per hour."
          );
        }
        
        // Only apply time limit if last request was successful
        if (lastRequestSuccess && now - lastRequest < 10000) { // Min 10 seconds between successful requests
          throw new HttpsError(
            "resource-exhausted",
            "Please wait 10 seconds between generation requests."
          );
        }
        
        await userRequestsRef.update({
          lastRequest: now,
          requestCount: requestCount + 1,
          lastRequestSuccess: null, // Will be updated after processing
        });
      }
    } else {
      await userRequestsRef.set({
        lastRequest: now,
        requestCount: 1,
        resetTime: now + (60 * 60 * 1000),
        lastRequestSuccess: null,
      });
    }

    let apiKey: string;
    try {
      apiKey = geminiApiKey.value();
      console.log("API Key retrieved successfully, length:", apiKey ? apiKey.length : 0);
    } catch (error) {
      console.error("Error retrieving API key:", error);
      throw new HttpsError(
        "failed-precondition",
        "Failed to retrieve GEMINI_API_KEY secret."
      );
    }

    if (!apiKey || apiKey.trim().length < 20) {
      console.error("GEMINI_API_KEY is missing or too short. Length:", apiKey ? apiKey.length : 0);
      throw new HttpsError(
        "failed-precondition",
        "GEMINI_API_KEY secret is missing or invalid."
      );
    }

    // Fetch remix doc
    const remixRef = db.collection("remixes").doc(remixId);
    const remixSnap = await remixRef.get();

    if (!remixSnap.exists) {
      throw new HttpsError("not-found", "Remix not found.");
    }

    const remix = remixSnap.data() as RemixDoc;

    // Validate auth: only owner can generate
    if (callerUid !== remix.userId) {
      console.error(`Access denied: ${callerUid} tried to access remix owned by ${remix.userId}`);
      throw new HttpsError(
        "permission-denied",
        "User does not have permission to access this remix."
      );
    }

    // Additional security checks
    if (remix.status === "generating") {
      throw new HttpsError(
        "failed-precondition",
        "Generation already in progress for this remix."
      );
    }

    // Validate image exists and is accessible
    console.log("Remix data:", JSON.stringify(remix, null, 2));
    
    if (!remix.originalImagePath || remix.originalImagePath.trim() === "") {
      console.error("Original image path is empty or undefined");
      throw new HttpsError(
        "failed-precondition",
        "Original image path is missing. Please upload a new image."
      );
    }

    const bucket = storage.bucket();
    const originalFile = bucket.file(remix.originalImagePath);
    const [exists] = await originalFile.exists();
    
    if (!exists) {
      console.error(`Original image not found at path: ${remix.originalImagePath}`);
      throw new HttpsError(
        "not-found",
        "Original image not found. Please upload a new image."
      );
    }

    try {
      // Update status → generating
      await remixRef.update({ status: "generating" });

      // Download original image from Storage
      const bucket = storage.bucket();
      const originalFile = bucket.file(remix.originalImagePath);
      const [buffer] = await originalFile.download();

      // Using Gemini 2.5 Flash Image - Google's image generation model (Nano Banana)
      // Features: New background, lighting/color grading changes, lifestyle look, scene variations
      const genAI = new GoogleGenerativeAI(apiKey);
      
      // Use the correct image generation model
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash-image",
      });

      // Convert buffer to base64 for Gemini
      const base64Image = buffer.toString("base64");

      // 3 different scene variations with specific transformations
      const scenePrompts = [
        {
          prompt: "Transform this portrait photo into a bright sunny beach travel scene. Change the background to a beautiful tropical beach with palm trees, crystal clear water, and golden sand. Adjust lighting to be warm and sunny, enhance colors to be vibrant and Instagram-worthy. Keep the person's face and pose natural, create a lifestyle look suitable for social media.",
          description: "Beach travel scene",
        },
        {
          prompt: "Transform this portrait into a neon-lit futuristic night city rooftop scene. Change the background to a modern city skyline at night with neon lights and urban atmosphere. Adjust lighting to be cinematic with cool tones and dramatic shadows. Apply color grading with blue and purple tones. Create a lifestyle look perfect for Instagram posts.",
          description: "City rooftop scene",
        },
        {
          prompt: "Transform this image into a cozy cafe lifestyle photo. Change the background to a warm, inviting cafe interior with soft natural lighting. Adjust color grading to warm tones with golden hour feel. Create a relaxed, lifestyle atmosphere suitable for social media. Keep the person natural and comfortable in the scene.",
          description: "Cafe lifestyle scene",
        },
      ];

      const generatedPaths: string[] = [];

      // Generate images using Gemini 2.5 Flash Image
      for (let i = 0; i < scenePrompts.length; i++) {
        const { prompt, description } = scenePrompts[i];
        console.log(`Generating scene ${i + 1}: ${description}`);

        let generatedBuffer: Buffer | null = null;
        let retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            console.log(`Attempting to generate scene ${i + 1} with model: gemini-2.5-flash-image (attempt ${retryCount + 1}/${maxRetries})`);

            // Generate image with Gemini Flash Image
            const result = await model.generateContent({
              contents: [
                {
                  role: "user",
                  parts: [
                    {
                      text: prompt,
                    },
                    {
                      inlineData: {
                        mimeType: "image/jpeg",
                        data: base64Image,
                      },
                    },
                  ],
                },
              ],
            });

            console.log(`Response received for scene ${i + 1}, checking for image data...`);

            // Extract generated image from response
            const response = result.response;
            const candidate = response.candidates?.[0];

            if (!candidate) {
              throw new Error(`No candidate in response for scene ${i + 1}`);
            }

            const imagePart = candidate.content.parts.find(
              (part: any) => part.inlineData
            );

            if (!imagePart || !imagePart.inlineData) {
              console.log(`Available parts:`, JSON.stringify(candidate.content.parts.map((p: any) => Object.keys(p))));
              throw new Error(
                `No image data in response for scene ${i + 1} - model may not support image generation or returned text only`
              );
            }

            // Convert base64 image data to buffer
            generatedBuffer = Buffer.from(imagePart.inlineData.data, "base64");
            console.log(
              `Successfully generated scene ${i + 1} using Gemini Flash Image, size: ${generatedBuffer.length} bytes`
            );

            // Success - break out of retry loop
            break;

          } catch (error: any) {
            retryCount++;
            console.error(`Error generating scene ${i + 1} (attempt ${retryCount}/${maxRetries}):`, error);

            if (retryCount >= maxRetries) {
              // Final attempt failed
              const errorMessage = error?.message || "Unknown generation error";
              
              // Provide more specific error messages
              let userFriendlyMessage = errorMessage;
              if (errorMessage.includes("quota")) {
                userFriendlyMessage = "API quota exceeded. Please try again later.";
              } else if (errorMessage.includes("invalid")) {
                userFriendlyMessage = "Invalid image or prompt. Please try with a different photo.";
              } else if (errorMessage.includes("timeout")) {
                userFriendlyMessage = "Generation timed out. Please try again.";
              } else if (errorMessage.includes("No image data")) {
                userFriendlyMessage = "AI model failed to generate image. Please try again.";
              }

              throw new Error(`Failed to generate scene ${i + 1} after ${maxRetries} attempts: ${userFriendlyMessage}`);
            }

            // Wait before retry (exponential backoff)
            const waitTime = Math.pow(2, retryCount) * 1000; // 2s, 4s, 8s
            console.log(`Waiting ${waitTime}ms before retry...`);
            await new Promise(resolve => setTimeout(resolve, waitTime));
          }
        }

        // Ensure we have a generated buffer before proceeding
        if (!generatedBuffer) {
          throw new Error(`Failed to generate scene ${i + 1}: No image data received`);
        }

        // Save generated image to Storage
        const outputPath = `images/${callerUid}/${remixId}/generated_${i + 1}.jpg`;
        const resultFile = bucket.file(outputPath);

        try {
          await resultFile.save(generatedBuffer, {
            contentType: "image/jpeg",
            metadata: {
              metadata: {
                scene: description,
                prompt: prompt,
                index: (i + 1).toString(),
                model: "gemini-2.5-flash-image",
                generatedAt: new Date().toISOString(),
              },
            },
          });

          generatedPaths.push(outputPath);
          console.log(`Successfully saved scene ${i + 1} to ${outputPath}`);

        } catch (storageError: any) {
          console.error(`Failed to save scene ${i + 1} to storage:`, storageError);
          throw new Error(`Failed to save generated image ${i + 1}: ${storageError.message}`);
        }
      }

      // Update Firestore
      await remixRef.update({
        generatedImagePaths: generatedPaths,
        status: "completed",
        errorMessage: null,
      });

      // Mark request as successful
      await userRequestsRef.update({
        lastRequestSuccess: true,
      });

      return {
        success: true,
        count: generatedPaths.length,
      };
    } catch (error: any) {
      console.error("AI generation failed:", error);

      const message = error?.message ?? "Unknown error";

      // Set Firestore to error state
      await remixRef.update({
        status: "error",
        errorMessage: message,
        generatedImagePaths: [],
      });

      // Mark request as failed (allows immediate retry)
      await userRequestsRef.update({
        lastRequestSuccess: false,
      });

      throw new HttpsError("internal", message);
    }
  }
);
