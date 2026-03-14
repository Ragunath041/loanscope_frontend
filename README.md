# Loan Scope – AI Based CIBIL Score Prediction System

Loan Scope is a financial application that predicts a user's future CIBIL score based on loan details and repayment behavior.

## Features:

- Predict future CIBIL score
- Loan input dashboard
- Financial education section
- Data-driven credit analysis
- Secure authentication

## Abstract

This project aims to develop an intelligent system to predict an individual's future CIBIL score using machine learning models. It leverages a Random Forest Regressor trained on historical financial data, including variables such as current CIBIL scores, loan amounts, credit card usage, and repayment histories, to accurately predict changes in credit behavior. The model dynamically analyzes how new loans, late payments, and other credit activities influence the future score, making it adaptable to a wide range of user profiles. The system's architecture includes a Flask-based backend that handles user registration, login, and the fetching of user financial data based on PAN numbers from a pre-existing database. By collecting user data through a CSV file, the model uses this input to generate a prediction for future CIBIL scores. It adjusts predictions based on factors such as new loans, penalties for late payments, and rewards for timely payments, providing users with insights into how their actions could impact their financial standing.

**Keywords:** Lending Decision, Loan Portfolio, Decision Tree, Random Forest, Prediction Model, Machine Learning, Pandas, Numpy, Scikit-learn, Pickle.

## Introduction

In today's financial landscape, maintaining a strong CIBIL score is crucial for accessing credit and securing favorable loan terms. However, borrowers often face uncertainty regarding how new loans or changes in their repayment behavior will affect their credit score. Loan Scope aims to bridge this gap by providing users with real-time insights into how their loan decisions—such as taking out a specific loan amount—can impact their CIBIL score. Loan Scope offers predictive analysis, showing users how their CIBIL score may decrease when a loan is taken and how it could recover over time with regular, on-time payments. By empowering users to see both the short-term and long-term effects of their financial decisions, this application serves as a valuable tool for responsible borrowing and better credit management.

## Existing System

Existing loan approval systems primarily rely on traditional methods that are often cumbersome and time-consuming. These systems typically use limited customer data, focusing more on personal information rather than financial indicators. Machine learning has been applied in some systems, but many fail to leverage advanced techniques for feature engineering and data preprocessing. As a result, accuracy rates in predicting loan defaults remain suboptimal. Furthermore, the systems lack flexibility in offering dynamic repayment options and tend to follow a one-size-fits-all approach.

## Proposed System

The proposed system, Loan Scope: Predicting Real-Time CIBIL Impact and Recovery, introduces a machine learning-based approach to enhance the loan evaluation and decision-making process. This system aims to provide users with personalized predictions on how taking out a loan will impact their CIBIL score and assess their risk of default. The core feature of this system is the CIBIL score prediction model, which uses regression algorithms to forecast the potential reduction in the score due to the loan. Unlike existing systems, this solution offers dynamic, scenario-based forecasting and integrates machine learning models to deliver personalized, data-driven predictions.

## Core Objectives & Algorithms

- **Linear Regression:** Predicts the immediate reduction in a user's CIBIL score based on loan parameters such as loan amount, tenure, and interest rates.
- **Multiple Linear Regression:** Accounts for multiple factors (loan amount, tenure, income, etc.) influencing the prediction to provide a more accurate estimate of the CIBIL score impact.
- **Logistic Regression:** Predicts the probability of loan default. It is a classification algorithm that estimates the likelihood of a loan default occurring based on input features such as loan amount, income, and repayment history.

## Application Interface

The application features a user-friendly interface that simplifies the process of inputting loan details and quickly obtaining predictions, making financial planning more accessible. The dashboard provides a comprehensive financial overview for the user, detailing sanctioned and current amounts for personal and home loans, along with the status of credit card activity. This allows users to foresee the impact of taking a loan before making financial commitments.

## Conclusion

The _Loan Scope_ project represents a significant advancement in the way individuals and financial institutions assess the implications of loan agreements on credit health. By leveraging machine learning algorithms, this application provides users with accurate predictions of how their CIBIL scores will be affected by various loan parameters, along with insights into the likelihood of default and potential recovery of credit scores over time. The insights generated by the Loan Scope application can also aid financial institutions in their lending processes. By better understanding the risk profiles of potential borrowers, lenders can make more informed decisions, tailor loan products to meet customer needs, and reduce the likelihood of defaults. Ultimately, this leads to improved credit management and promotes responsible borrowing behavior.
