// Predefined service types for each business category
export const SERVICE_TYPES_BY_CATEGORY: Record<string, string[]> = {
  "Beauty & Wellness": [
    "Haircut",
    "Hair Coloring",
    "Blowdry & Styling",
    "Beard Trim",
    "Manicure",
    "Pedicure",
    "Gel Nails",
    "Facial",
    "Waxing",
    "Eyebrow Shaping",
    "Eyelash Extensions",
    "Makeup",
    "Massage",
    "Other"
  ],
  Healthcare: [
    "General Consultation",
    "Dental Checkup",
    "Dental Cleaning",
    "Teeth Whitening",
    "Physiotherapy Session",
    "Blood Test",
    "X-Ray",
    "Vaccination",
    "Health Screening",
    "Eye Exam",
    "Other"
  ],
  "Fitness & Sports": [
    "Personal Training",
    "Group Fitness Class",
    "Yoga Session",
    "Pilates",
    "Spinning Class",
    "Boxing Training",
    "Swimming Lesson",
    "Nutrition Consultation",
    "Fitness Assessment",
    "Other"
  ],
  "Professional Services": [
    "Legal Consultation",
    "Accounting Service",
    "Tax Preparation",
    "Business Consulting",
    "Financial Planning",
    "Marketing Consultation",
    "IT Support",
    "Career Coaching",
    "Other"
  ],
  "Education & Tutoring": [
    "Math Tutoring",
    "English Tutoring",
    "Science Tutoring",
    "Language Lesson",
    "Music Lesson",
    "Art Class",
    "Test Prep",
    "Online Course",
    "Other"
  ],
  "Pet Services": [
    "Dog Grooming",
    "Cat Grooming",
    "Pet Bath",
    "Nail Trimming",
    "Vet Consultation",
    "Pet Training",
    "Dog Walking",
    "Pet Sitting",
    "Other"
  ],
  Automotive: [
    "Car Wash",
    "Interior Detailing",
    "Exterior Detailing",
    "Full Detailing",
    "Oil Change",
    "Tire Change",
    "Vehicle Inspection",
    "Car Repair",
    "Other"
  ],
  "Photography & Video": [
    "Portrait Session",
    "Event Photography",
    "Wedding Photography",
    "Product Photography",
    "Video Editing",
    "Studio Session",
    "Photo Retouching",
    "Other"
  ],
  "Therapy & Counseling": [
    "Individual Therapy",
    "Couples Therapy",
    "Family Therapy",
    "Life Coaching",
    "Career Counseling",
    "Stress Management",
    "Mental Health Consultation",
    "Other"
  ],
  Other: ["Other"]
};

// Get all unique predefined services (excluding "Other")
export const getAllPredefinedServices = (): string[] => {
  const allServices = new Set<string>();

  Object.values(SERVICE_TYPES_BY_CATEGORY).forEach((services) => {
    services.forEach((service) => {
      if (service !== "Other") {
        allServices.add(service);
      }
    });
  });

  return Array.from(allServices).sort();
};

// Get services for a specific category
export const getServicesForCategory = (category: string): string[] => {
  return SERVICE_TYPES_BY_CATEGORY[category] || ["Other"];
};
