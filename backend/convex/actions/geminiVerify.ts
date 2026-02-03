// convex/actions/geminiVerify.ts
// Certificate verification with Gemini 3 Flash

"use node";

import { internalAction } from "../_generated/server";
import { v } from "convex/values";
import { internal } from "../_generated/api";

const GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash:generateContent";

export const verifyCertificate = internalAction({
  args: {
    verificationId: v.id("verifications"),
  },
  handler: async (ctx, { verificationId }) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      throw new Error("GEMINI_API_KEY not configured");
    }
    
    // Get verification record
    const verification = await ctx.runQuery(internal.verifications.getById, {
      verificationId,
    });
    if (!verification) throw new Error("Verification not found");
    
    // Get user for name matching
    const user = await ctx.runQuery(internal.users.getUserById, {
      userId: verification.userId,
    });
    if (!user) throw new Error("User not found");
    
    // Fetch document from Convex storage
    const docResponse = await fetch(verification.docUrl);
    const docBuffer = await docResponse.arrayBuffer();
    const base64 = Buffer.from(docBuffer).toString("base64");
    
    const mimeType = verification.docUrl.endsWith(".pdf") 
      ? "application/pdf" 
      : "image/jpeg";
    
    // Build Gemini prompt
    const prompt = `You are verifying an Israeli fitness instructor certificate.

CLAIMED NAME: ${user.name}
CLAIMED HEBREW NAME: ${user.nameHebrew || "Not provided"}

TASK:
1. Extract ALL text from this document (Hebrew and English)
2. Identify the certificate holder's name
3. Compare with claimed name - handle variations:
   - Hebrew <-> English transliteration (יוסי = Yossi = Jossi = Yosi)
   - Nicknames (יוסף = יוסי, דוד = דודי, מיכאל = מיקי)
   - Name order differences
4. Extract certificate details
5. Check for signs of tampering or forgery
6. Determine if certificate is expired

RETURN ONLY VALID JSON:
{
  "extractedName": "Name as it appears on certificate",
  "extractedNameHebrew": "Hebrew name if present",
  "nameMatchScore": 0.0-1.0,
  "issuingAuthority": "e.g., Wingate Institute",
  "certificateNumber": "if visible",
  "issueDate": "YYYY-MM-DD or null",
  "expiryDate": "YYYY-MM-DD or null",
  "isExpired": true/false,
  "certificationType": "e.g., Personal Trainer, Group Fitness",
  "confidence": 0.0-1.0,
  "flags": ["list of concerns if any"],
  "recommendation": "approve" | "review" | "reject"
}

RECOMMENDATION RULES:
- "approve": nameMatchScore >= 0.85 AND confidence >= 0.8 AND !isExpired AND flags.length === 0
- "review": nameMatchScore >= 0.6 OR confidence >= 0.6 OR flags.length > 0
- "reject": nameMatchScore < 0.6 AND confidence < 0.5`;

    const response = await fetch(GEMINI_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            {
              inline_data: {
                mime_type: mimeType,
                data: base64,
              },
            },
          ],
        }],
        generationConfig: {
          responseMimeType: "application/json",
        },
      }),
    });
    
    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Gemini API error: ${error}`);
    }
    
    const result = await response.json();
    const analysisText = result.candidates?.[0]?.content?.parts?.[0]?.text;
    
    if (!analysisText) {
      throw new Error("No analysis returned from Gemini");
    }
    
    const analysis = JSON.parse(analysisText);
    
    // Determine final status
    let status: "verified" | "rejected" | "manual_review";
    if (analysis.recommendation === "approve") {
      status = "verified";
    } else if (analysis.recommendation === "reject") {
      status = "rejected";
    } else {
      status = "manual_review";
    }
    
    // Update verification record
    await ctx.runMutation(internal.verifications.updateWithAnalysis, {
      verificationId,
      aiAnalysis: analysis,
      status,
    });
    
    // If verified, update user's verified status
    if (status === "verified") {
      await ctx.runMutation(internal.users.setVerified, {
        userId: verification.userId,
        verified: true,
      });
    }
    
    return { status, analysis };
  },
});
