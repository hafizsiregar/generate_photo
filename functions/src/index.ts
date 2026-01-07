import {
  onCall,
  HttpsError,
} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

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
    timeoutSeconds: 540,
    memory: "1GiB",
    maxInstances: 10,
  },
  async (request) => {
    console.log("generateImages called");

    const remixId = request.data?.remixId;
    if (!remixId) {
      throw new HttpsError("invalid-argument", "remixId is required.");
    }

    console.log("Processing remixId:", remixId);

    // Get API key from environment variable
    const apiKey = process.env.GEMINI_API_KEY;
    console.log("API Key retrieved successfully, length:", apiKey ? apiKey.length : 0);
    console.log("API Key first 10 chars:", apiKey ? apiKey.substring(0, 10) : 'null');

    if (!apiKey || apiKey.trim().length < 20) {
      console.error("GEMINI_API_KEY is missing or too short");
      throw new HttpsError(
        "failed-precondition",
        "GEMINI_API_KEY environment variable is missing or invalid."
      );
    }

    // Fetch remix doc
    const remixRef = db.collection("remixes").doc(remixId);
    const remixSnap = await remixRef.get();

    if (!remixSnap.exists) {
      throw new HttpsError("not-found", "Remix not found.");
    }

    const remix = remixSnap.data() as RemixDoc;
    console.log("Processing remix for user:", remix.userId);

    if (remix.status === "generating") {
      throw new HttpsError(
        "failed-precondition",
        "Generation already in progress for this remix."
      );
    }

    if (!remix.originalImagePath || remix.originalImagePath.trim() === "") {
      console.error("Original image path is empty");
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
      // Update status to generating
      await remixRef.update({ status: "generating" });

      // Download original image
      const [buffer] = await originalFile.download();

      // Initialize Gemini
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-2.5-flash-image",
      });

      const base64Image = buffer.toString("base64");

      // Scene prompts
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

      // Generate images
      for (let i = 0; i < scenePrompts.length; i++) {
        const { prompt, description } = scenePrompts[i];
        console.log(`Generating scene ${i + 1}: ${description}`);

        try {
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

          const candidate = result.response.candidates?.[0];
          if (!candidate) {
            throw new Error(`No candidate in response for scene ${i + 1}`);
          }

          const imagePart = candidate.content.parts.find(
            (part: any) => part.inlineData
          );

          if (!imagePart || !imagePart.inlineData) {
            throw new Error(`No image data in response for scene ${i + 1}`);
          }

          const generatedBuffer = Buffer.from(imagePart.inlineData.data, "base64");
          console.log(`Successfully generated scene ${i + 1}, size: ${generatedBuffer.length} bytes`);

          // Save to storage
          const outputPath = `images/${remix.userId}/${remixId}/generated_${i + 1}.jpg`;
          const resultFile = bucket.file(outputPath);

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

        } catch (error: any) {
          console.error(`Error generating scene ${i + 1}:`, error);
          // Continue with other scenes
        }
      }

      // Update Firestore
      await remixRef.update({
        generatedImagePaths: generatedPaths,
        status: "completed",
        errorMessage: null,
      });

      return {
        success: true,
        count: generatedPaths.length,
      };

    } catch (error: any) {
      console.error("Generation failed:", error);

      const message = error?.message ?? "Unknown error";

      // Set Firestore to error state
      await remixRef.update({
        status: "error",
        errorMessage: message,
        generatedImagePaths: [],
      });

      throw new HttpsError("internal", message);
    }
  }
);